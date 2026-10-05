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
| zsh `ls`/completion colors | `$TERMINAL_THEME` → a `_THEME_SPEC` row | `zsh/.config/zsh/theme.zsh` |
| oh-my-posh prompt | palette `template` on `$TERMINAL_THEME` | `ohmyposh/.config/ohmyposh/zen.omp.json` |
| Claude Code statusline | reads the file each render | `claude/.claude/commands/statusline-palette.sh` |
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

A theme is each machine's own choice: `prefix t` on the office mini switches
the mini alone, and nothing carries the laptop's pick across.

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

Consequences worth internalizing:

- **The statusline reads the file, not the env, on purpose.** A running Claude
  session inherited a now-stale `$TERMINAL_THEME` from its launching shell;
  reading the file each render lets it track switches anyway.
- **Inside tmux the file must still win — and it does, two ways.** A tmux
  server snapshots `TERMINAL_THEME` the first time it launches and seeds it
  into every pane it spawns, so a shell that trusted the inherited value would
  pin every pane to the theme active at server start. `theme.zsh` reads
  `~/.config/terminal-theme` **unconditionally**, and `theme-set` runs
  `tmux set-environment -g TERMINAL_THEME` so the server's env tracks the
  switch too; new or renamed themes need no extra work. A
  `-z "$TERMINAL_THEME"` guard around that read is the bug, and
  `zsh/.config/zsh/tests/theme-sync.test.zsh` pins the file beating an
  inherited value.
- **Ghostty can't be driven on macOS.** `theme-set` makes the *content* correct
  immediately; the *reload* is a manual keystroke. This is accepted, not a bug.
- **A running shell catches up on its own, but only at a prompt.**
  `theme.zsh`'s `_theme_sync` precmd re-applies everything the theme owns when
  the file's name changed, and runs ahead of oh-my-posh's precmd, so the very
  next prompt uses the new palette, including in a shell that a foreground
  `claude` held during the switch (the ordering is explained in `theme.zsh`).
  The hook is interactive-only; `zsh/.config/zsh/tests/theme-sync.test.zsh`
  pins it.

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

Tab and divider styling belongs to each theme's tmux palette file
(`@thm_window_*` slots, divider geometry reset on each switch), not to shared
accents; keep the selected tab distinct in brightness as well as hue.

## Codex CLI syntax colors

Codex's `tui.theme` independently selects a `.tmTheme` under `~/.codex/themes`.
The Moon port matches the terminal palette. `theme-set` does not change this
selection: use `/theme`
in a running Codex CLI to preview and select it, or edit
`twin/.config/twin/codex/shared.toml`, run `twin dotfiles apply` and restart
(`docs/twin.md` § Codex config; a `/theme` pick made in the CLI is local drift
until it is moved there). It colors code blocks and diffs; terminal colors
still supply the surrounding UI. See [Codex CLI customization](https://learn.chatgpt.com/docs/cli-customization).

## Neovim specifics

- Colorschemes come from two places: **plugin themes** (catppuccin, gruvbox) and
  **hand-rolled files** in `colors/`, ported from a Zed or VS Code theme's UI
  and syntax tokens; a port's header names its source and the deviations it
  keeps on purpose.
- The plugin themes are **un-gated** (all installed; the active one eager, the
  rest lazy) so the watcher can swap *any* direction — lazy.nvim's
  `ColorSchemePre` autoloads the matching plugin on `:colorscheme`.
- `lua/config/theme.lua` owns the name: it reads the file, maps the name to a
  colorscheme and background, and holds the file watcher (`M.watch`, started
  from `lua/config/autocmds.lua`; polls, not `fs_event` — the latter goes stale
  on macOS atomic renames).
- The lualine band takes its colours from the active colorscheme:
  `StatusLine` bg, `Normal` fg, and `Comment` fg for secondary text. A
  hand-rolled scheme sets its band on its `StatusLine` line; a plugin scheme
  whose `StatusLine` reads as no band gets an entry in `lua/plugins/ui.lua`'s
  `band_override`. Lualine re-reads the colours on `ColorScheme`, so the band
  follows a live switch.
