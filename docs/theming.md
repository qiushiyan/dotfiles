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
- The default when no selection exists is `gruber_darker`.
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

Per-tool palettes preserve hand-tuned contrast; a shared colour generator would
remove that control. Theme additions follow `/add-theme`.

## Model 2 — the control plane

**`theme-set`** (`scripts/.local/bin/theme-set`, on `PATH`) is the one writer.
It validates the name, writes `~/.config/terminal-theme`, regenerates the
Ghostty include, and re-sources tmux. It is UI-agnostic on purpose: the tmux
`prefix t` menu, the CLI, and anything added later all call the same script.

The picker is a native tmux `display-menu` bound to `prefix t` (overrides
clock-mode) — defined in `tmux.conf`. It opens with the current theme selected;
the palette loader maps the canonical theme name to `display-menu -C`'s row.

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

`config-file = ?auto/theme.ghostty` pulls in a **switcher-owned, gitignored**
include. `theme-set` fully regenerates it on every switch; manual edits there
are disposable. Extend `ghostty_block()` for theme-specific settings.

The include is last, so its explicit settings override base settings. Settings
it omits inherit from the base config. Explicit colour overrides also take
precedence over colours supplied by a theme: a fixed `background` in the base
config persists across theme switches unless explicitly overridden. The base
background is intentionally tuned to Terminal's Moon appearance; inspect it
when another theme appears to retain the same background.

Font selection belongs to the base config → `docs/ghostty-fonts.md`.
`bold-color` belongs to each theme: dark backgrounds need brighter emphasis,
light backgrounds need deeper ink. A literal colour reaches default-foreground
bold text; `bright` alone only affects text carrying ANSI colours.

**Literal `bold-color` can override an explicit text colour equal to the default
foreground.** On light themes that includes tmux's `@thm_crust`. Avoid `bold`
on crust/foreground text over coloured selections; use `@thm_mode_bg` for a
selection colour with enough contrast. The palette loader resets that slot on
switching, so a theme-specific selection cannot leak into another theme.

## Comparing terminal colours

**RGB values only identify a colour together with their colour space.**
Ghostty uses sRGB here. Terminal profiles can store Apple Generic RGB colours:
the inspected Moon background's `#222436` converts through macOS to roughly
`#2d3146` in sRGB. Equal hex strings therefore do not establish a visual match;
switching Ghostty between P3 and sRGB alone barely changes this dark background.
Convert the profile's tagged colours into a common space before comparing them.
[Apple colour spaces](https://developer.apple.com/documentation/appkit/nscolorspace/genericrgb),
[Ghostty colour space](https://ghostty.org/docs/config/reference#window-colorspace).

For tmux tab styling, use the theme's `@thm_window_*` slots rather than changing
shared accents. Moon gives inactive tabs muted backgrounds and lavender text;
the selected tab gets a purple badge and near-white name. The palette file owns
the exact values. Keep the selected state distinct in brightness as well as hue.

## Neovim specifics

- Colorschemes come from two places: **plugin themes** (catppuccin, gruvbox) and
  **hand-rolled files** in `colors/` (ported from a Zed or VS Code theme's UI +
  syntax tokens).
- Vellum defines Snacks picker hidden/ignored paths, Git markers, and result
  counts explicitly; their default `NonText` link is too pale for readable text.
- Gruber Darker is a local port of the installed Zed extension (0.0.8), including
  the Zed settings' yellow Markdown titles and italic syntax. It replaces the
  earlier Neovim-only plugin. `config/options.lua` applies the selected
  light/dark mode before a colorscheme loads, independently of theme plugins.
- The plugin themes are **un-gated** (all installed; the active one eager, the
  rest lazy) so the watcher can swap *any* direction — lazy.nvim's
  `ColorSchemePre` autoloads the matching plugin on `:colorscheme`.
- The file watcher lives in `lua/config/autocmds.lua` (polls, not `fs_event` —
  the latter goes stale on macOS atomic renames). The name→colorscheme map is in
  `lua/config/theme.lua`; `lua/config/palette.lua` feeds the custom statusline.
