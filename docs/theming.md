# Terminal theming

How one theme choice propagates to every terminal-side tool — shell colors,
prompt, Claude statusline, tmux, Neovim, Ghostty — and how switching works.

> Scope: the "scene" you see inside a terminal. GUI apps (Zed, etc.) manage
> their own appearance and are deliberately **out of scope** — this system stops
> at the terminal boundary.

## TL;DR

- One canonical name lives in **`~/.config/terminal-theme`** (e.g.
  `tailwind_light`). That file is the single source of truth.
- Each tool maps that name to its **own hand-tuned palette**. Palettes are
  authored per tool, not generated from a central spec.
- **`theme-set <name>`** writes the name and fans out reloads;
  **`prefix t`** in tmux is the picker that calls it.
- The valid names are the `THEMES` array in `theme-set` (`theme-set` with no
  argument prints them); adding one is `/add-theme`.

## Model 1 — a name in a file, a palette per tool

`~/.config/terminal-theme` holds a single token. `$TERMINAL_THEME` (exported by
zsh at startup, re-read from the file on every shell launch so it can't go
stale — see Model 3) is just a cached copy of it for shell-side consumers. Every tool
resolves that name and looks up **its own** palette — there is no shared color
table.

| Consumer | reads the name via | palette lives in |
|---|---|---|
| zsh `ls`/completion colors | `case "$TERMINAL_THEME"` | `zsh/.config/zsh/theme.zsh` |
| oh-my-posh prompt | palette `template` on `$TERMINAL_THEME` | `ohmyposh/.config/ohmyposh/zen.omp.json` |
| Claude Code statusline | reads the file each render | `claude/.claude/commands/statusline-command.sh` |
| tmux | reads the file when the config loads | `tmux/.config/tmux/tmux.conf` + `tmux/.config/tmux/themes/<theme>_tmux.conf` |
| Neovim | reads file/env at startup, then watches the file | `nvim/.config/nvim/lua/config/theme.lua`, `colors/`, `lua/plugins/theme.lua` |
| Ghostty | a generated include file | `ghostty/.config/ghostty/auto/theme.ghostty` (+ `themes/`, `config`) |

**Why per-tool palettes and not a generator** (base16 / tinty / pywal): those
tools generate every app's colors from one scheme spec. Here the palettes are
hand-tuned and the tool count is small (~6), so a generator adds a dependency
and takes away the hand-tuning while buying nothing. The cost is that adding a
theme touches each tool once (the `/add-theme` skill walks them).

## Model 2 — the control plane

**`theme-set`** (`scripts/.local/bin/theme-set`, on `PATH`) is the one writer.
It validates the name, writes `~/.config/terminal-theme`, regenerates the
Ghostty include, and re-sources tmux. It is UI-agnostic on purpose: the tmux
`prefix t` menu, the CLI, and anything added later all call the same script.

The picker is a native tmux `display-menu` bound to `prefix t` (overrides
clock-mode) — defined in `tmux.conf`.

## Model 3 — reload is not uniform; Ghostty is the weak link

Switching the name is instant; making each tool *re-read* it is not. This matrix
is the load-bearing mental model:

| Tool | how it reloads | live? |
|---|---|---|
| tmux | `theme-set` re-sources the config | ✅ |
| Neovim | each instance polls the file and re-applies `:colorscheme` | ✅ (instances older than the watcher need a restart) |
| Claude statusline | re-renders constantly, reads the file each draw | ✅ |
| Ghostty | include is rewritten, but **macOS has no external config reload** (the `SIGUSR2` reload is Linux-only) | ⚠️ press **⌘⇧,** |
| zsh prompt / `ls` colors | `_theme_sync` precmd re-reads the file before each prompt and re-applies on change | ✅ (next prompt; a shell held by a foreground command catches up when it returns) |

Four consequences worth internalizing:

- **The statusline reads the file, not the env, on purpose.** A running Claude
  session inherited a now-stale `$TERMINAL_THEME` from its launching shell;
  reading the file each render lets it track switches anyway.
- **Inside tmux the file must still win — and it does, two ways.** A tmux server
  snapshots `TERMINAL_THEME` into its environment the first time it launches and
  seeds that value into *every* pane it spawns afterward. A shell that trusted
  the inherited value would therefore pin all panes to whatever theme was active
  when the server started — stale forever after a switch, so the prompt renders
  one palette inside tmux and another outside it. Two defenses keep the file
  authoritative: `theme.zsh` reads `~/.config/terminal-theme` **unconditionally**
  (it is *not* gated on `$TERMINAL_THEME` already being set), and `theme-set`
  runs `tmux set-environment -g TERMINAL_THEME` so the server's own env tracks
  the switch too. This is generic — new or renamed themes need no extra work for
  it. ⚠️ Don't reintroduce a `-z "$TERMINAL_THEME"` guard around the read in
  `theme.zsh`: that one line *is* the bug, and it only surfaces inside tmux, so
  it's easy to "optimize" back in without noticing.
- **Ghostty can't be driven on macOS.** `theme-set` makes the *content* correct
  immediately; the *reload* is a manual keystroke. This is accepted, not a bug.
- **A running shell catches up on its own, but only at a prompt.** `theme.zsh`
  wraps everything it owns (`TERMINAL_THEME`, `LSCOLORS`, the autosuggest
  style, delta/difftastic mode) in `_theme_apply` and registers a `_theme_sync`
  precmd that re-reads the file and re-applies only when the name changed. It
  is registered from `.zshenv`, so it sits in `precmd_functions` ahead of
  oh-my-posh's `_omp_precmd` (registered at the end of `.zshrc`); omp spawns
  its renderer with the shell's current env each prompt, so the very next
  prompt already uses the new palette. The case that bought this: switching
  themes from `prefix t` while `claude` held a shell in the foreground — that
  shell drew its first post-exit prompt in the old palette until `exec zsh`.
  Cost is one builtin `read` + a compare per prompt (~25 µs); the hook is
  interactive-only. `zsh/.config/zsh/tests/theme-sync.test.zsh` pins it.

## Ghostty: the include seam

Ghostty's config can't read env vars and can't be reloaded externally on macOS.
So `config-file = ?auto/theme.ghostty` at the bottom of `config` pulls in a
**switcher-owned, gitignored** include (`auto/` is ignored — it never enters the
repo). `theme-set` **fully regenerates** that include on every switch.

Full regeneration is also what makes Ghostty **multi-field**: a theme's block can
set `background-opacity`, `background-blur-radius`, … not just `theme`. Rewriting
the whole file means a field dropped from a theme can never linger as a stale
key. Fields a theme omits fall back to the base values in `config` (the include
is last, so it wins); extend `ghostty_block()` in `theme-set` to switch more.

Two fields ship today. `theme` is the obvious one. **`bold-color` is per-theme
because no single value works on both backgrounds** — dark themes take a warmer,
brighter accent than their foreground, light themes a deeper, more saturated one,
since going brighter on white loses contrast. It exists because Dank Mono's bold
is only ~12% heavier than its regular, so weight alone can't mark emphasis and
colour does the job instead → `docs/ghostty-fonts.md`.

## Neovim specifics

- Colorschemes come from two places: **plugin themes** (catppuccin, flexoki) and
  **hand-rolled files** in `colors/` (ported from a Zed or VS Code theme's UI +
  syntax tokens).
- The plugin themes are **un-gated** (all installed; the active one eager, the
  rest lazy) so the watcher can swap *any* direction — lazy.nvim's
  `ColorSchemePre` autoloads the matching plugin on `:colorscheme`.
- The file watcher lives in `lua/config/autocmds.lua` (polls, not `fs_event` —
  the latter goes stale on macOS atomic renames). The name→colorscheme map is in
  `lua/config/theme.lua`; `lua/config/palette.lua` feeds the custom statusline.

## Adding or removing a theme

The recipe is the project skill `/add-theme` (`.claude/skills/add-theme/SKILL.md`):
one touch per tool, the exemplar to copy for each, the proof commands, and the
commit. Removing one is the reverse of its commit — `git revert` — since every
theme's files land in a single commit.
