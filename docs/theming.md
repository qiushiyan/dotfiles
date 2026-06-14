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
- Supported themes: `flexoki_light`, `catppuccin_mocha`, `tailwind_light`.

## Model 1 — a name in a file, a palette per tool

`~/.config/terminal-theme` holds a single token. `$TERMINAL_THEME` (exported by
zsh at startup) is just a cached copy of it for shell-side consumers. Every tool
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
theme touches each tool once (see *Adding a theme*).

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
| zsh prompt / `ls` colors | per-shell env, fixed at startup | ⚠️ new shells, or `exec zsh` |

Two consequences worth internalizing:

- **The statusline reads the file, not the env, on purpose.** A running Claude
  session inherited a now-stale `$TERMINAL_THEME` from its launching shell;
  reading the file each render lets it track switches anyway.
- **Ghostty can't be driven on macOS.** `theme-set` makes the *content* correct
  immediately; the *reload* is a manual keystroke. This is accepted, not a bug.

## Ghostty: the include seam

Ghostty's config can't read env vars and can't be reloaded externally on macOS.
So `config-file = ?auto/theme.ghostty` at the bottom of `config` pulls in a
**switcher-owned, gitignored** include (`auto/` is ignored — it never enters the
repo). `theme-set` **fully regenerates** that include on every switch.

Full regeneration is also what makes Ghostty **multi-field**: a theme's block can
set `background-opacity`, `background-blur-radius`, … not just `theme`. Rewriting
the whole file means a field dropped from a theme can never linger as a stale
key. Today every theme sets only `theme`; extend `ghostty_block()` in `theme-set`
to switch more. Fields a theme omits fall back to the base values in `config`
(the include is last, so it wins).

## Neovim specifics

- Colorschemes come from two places: **plugin themes** (catppuccin, flexoki) and
  **hand-rolled files** in `colors/` (the Tailwind variants, ported from the Zed
  theme's UI + syntax tokens).
- The plugin themes are **un-gated** (all installed; the active one eager, the
  rest lazy) so the watcher can swap *any* direction — lazy.nvim's
  `ColorSchemePre` autoloads the matching plugin on `:colorscheme`.
- The file watcher lives in `lua/config/autocmds.lua` (polls, not `fs_event` —
  the latter goes stale on macOS atomic renames). The name→colorscheme map is in
  `lua/config/theme.lua`; `lua/config/palette.lua` feeds the custom statusline.

## Adding a theme

Mechanical, one touch per tool — the cost of hand-tuned palettes. For `<name>`:

1. `theme-set` — add to `THEMES` and `ghostty_block()`.
2. zsh — a `case` arm in `theme.zsh`.
3. statusline — a `case` arm (six color slots) in `statusline-command.sh`.
4. oh-my-posh — a `palettes.list` entry in `zen.omp.json`.
5. tmux — `themes/<name>_tmux.conf` + a branch in the selector `case` in `tmux.conf`.
6. Neovim — a `map` entry in `config/theme.lua` + a colorscheme (a `colors/` file or a plugin spec).
7. Ghostty — a palette in `themes/` (or a built-in name).
8. Add a `display-menu` row to the `prefix t` binding.

After editing the oh-my-posh config, run `oh-my-posh cache clear` once — it caches
the parsed config and won't see a newly added palette otherwise.
