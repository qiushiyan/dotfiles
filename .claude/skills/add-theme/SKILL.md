---
name: add-theme
description: Port a color theme into the terminal theme system — one palette per tool, proven with theme-set, switched on, committed.
disable-model-invocation: true
---

# Add a terminal theme

One name in `~/.config/terminal-theme`; every terminal-side tool maps that name
to its own hand-tuned palette. A theme is done when each of the nine surfaces
below has one, `theme-set <name>` reports every reload, and the commit is in.
`docs/theming.md` is the system model — why palettes are per tool, how a
switch propagates, the Ghostty include seam — for when a tool does not pick the
switch up; the recipe needs none of it.

Copy the nearest **exemplar** rather than composing from scratch: `git show
<commit>` of a past port lists every touch. Dark → `forest_night` (hand-rolled
Neovim scheme) or `night_owl` (plugin scheme); light → `orng_light`. Every
value stays in-family — the theme's own tokens — and where a token fails
contrast on the theme's background, take a darker or lighter hue from the same
theme and say which in the comment beside it.

## 1. Get the palette

Needed: background, foreground, the 16 ANSI colors, the accent, two or three
surface elevations (selection, an elevated panel, a darker mantle), and, for a
hand-rolled Neovim scheme, the syntax token map.

| source | where it is |
|---|---|
| Zed theme (installed extension) | `~/Library/Application Support/Zed/extensions/installed/<ext>/themes/*.json` — `.themes[] \| select(.name=="…") \| .style` carries `background`, `editor.foreground`, `terminal.ansi.*`, `syntax.*` |
| Ghostty built-in | `/Applications/Ghostty.app/Contents/Resources/ghostty/themes/<Name>` — 16 palette lines plus bg/fg; theme-set then says `theme = <Name>` and no `themes/` file is written |
| a repo (Omarchy `colors.toml`, a VS Code theme) | `git clone --depth 1` into the scratchpad; VS Code theme JSON is JSONC, so strip comments before parsing |

```bash
# VS Code theme → the token map (foreground, fontStyle, scope) and the UI colors
node -e '
const fs=require("fs");let s=fs.readFileSync(process.argv[1],"utf8");
s=s.replace(/\/\*[\s\S]*?\*\//g,"").replace(/(^|[^:"])\/\/.*$/gm,"$1").replace(/,(\s*[}\]])/g,"$1");
const t=JSON.parse(s);
for(const [k,v] of Object.entries(t.colors||{})) if(/editor\.|terminal\.|selection|indentGuide|diffEditor|gitDecoration/.test(k)) console.log(k,v);
for(const tc of t.tokenColors||[]) console.log((tc.settings.foreground||"-").padEnd(9),(tc.settings.fontStyle||"").padEnd(12),"|",String(tc.scope).slice(0,120));
' themes/forest-night-color-theme.json
# → editor.background #1a2125 … / #F39C12   bold  | keyword.control.flow, …
```

## 2. Name it

`<name>` is snake_case: `forest_night`. The per-tool files use dashes —
Ghostty `themes/forest-night`, Neovim `colors/forest-night.lua` and colorscheme
`forest-night` — except tmux, `themes/forest_night_tmux.conf`.

## 3. The three new files

- **Ghostty** `ghostty/.config/ghostty/themes/<name-dashed>` — 16 `palette =
  N=#hex` lines plus `background`, `foreground`, `cursor-color`,
  `selection-background`, `selection-foreground`. Slot 8 (bright black) is the
  zsh autosuggestion color: it must read on the background (≈4:1 — forest_night
  took the theme's `#6b7280` over its own `#4a5568`). A Ghostty built-in theme
  needs no file.
- **tmux** `tmux/.config/tmux/themes/<name>_tmux.conf` — copy the exemplar; its
  header explains each slot. The decisions: `overlay_2` (inactive window badge)
  and `mauve` (active badge) are two accents; `green` is the session pill;
  `surface_1` (active name chip) sits one step lighter than `surface_0`; `crust`
  stays near-black for the numerals drawn on the badges.
- **Neovim**, one of two:
  - hand-rolled `nvim/.config/nvim/colors/<name-dashed>.lua` — copy the
    exemplar group for group and map the source's token colors onto it
    (keywords, functions, strings, properties, types, constants, comments;
    diff and diagnostic tints blended onto the background);
  - a plugin: a spec in `nvim/.config/nvim/lua/plugins/theme.lua` in the shape of
    the `night-owl.nvim` entry (`priority = 1000`, `lazy = theme.name ~=
    "<name>"`), installed with `nvim --headless "+Lazy! install" +qa`. Then
    `git diff nvim/.config/nvim/lazy-lock.json` shows exactly one added line;
    `Lazy! sync` would also re-pin unrelated plugins.

## 4. Patch the six shared files

Each file has a last arm; the new arm goes after it. Run this as one script so
a wrong anchor fails before anything is written; the values shown are
forest_night's — replace every color, keep every anchor.

```bash
cd ~/dotfiles && python3 - <<'PY'
import pathlib, sys
def patch(path, old, new):
    p = pathlib.Path(path); s = p.read_text()
    if s.count(old) != 1: sys.exit(f"{path}: anchor found {s.count(old)}x:\n{old!r}")
    p.write_text(s.replace(old, new)); print("patched", path)

# theme-set: the name list, and the ghostty block. bold-color: dark → warmer and
# brighter than fg (the bright yellow); light → deeper and more saturated than fg.
patch("scripts/.local/bin/theme-set", "night_owl orng_light)", "night_owl orng_light forest_night)")
patch("scripts/.local/bin/theme-set",
      "    orng_light)       printf 'theme = orng-light\\nbold-color = #c94d24\\n' ;;\n",
      "    orng_light)       printf 'theme = orng-light\\nbold-color = #c94d24\\n' ;;\n"
      "    forest_night)     printf 'theme = forest-night\\nbold-color = #FFB74D\\n' ;;\n")

# zsh: copy the nearest arm whole. Dark arms: bold dir + fg=8 + dark-mode;
# light arms: plain dir + fg=242 + light-mode. Only the comment changes.
patch("zsh/.config/zsh/theme.zsh",
      "    *)\n        print -ru2 \"theme.zsh: unknown TERMINAL_THEME '$TERMINAL_THEME'\"\n",
      "    forest_night)\n"
      "        # Blue-slate bg (#1a2125): bold/bright dir for emphasis, same as the other dark arms.\n"
      "        export LSCOLORS='Gxfxcxdxbxegedabagacad'\n"
      "        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'\n"
      "        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'\n"
      "        export DELTA_FEATURES='+dark-mode'\n"
      "        export DFT_BACKGROUND='dark'\n"
      "        ;;\n"
      "    *)\n        print -ru2 \"theme.zsh: unknown TERMINAL_THEME '$TERMINAL_THEME'\"\n")

# Claude statusline: six truecolor slots, decimal RGB (printf '%d;%d;%d' 0x4E 0xCD 0xC4).
# Slots owe contrast on the bg, not fidelity: swap in an in-family hue when one washes out.
patch("claude/.claude/commands/statusline-command.sh",
      "    *)\n        echo \"statusline: unknown theme '$THEME'\" >&2\n",
      "    forest_night)\n"
      "        # Blue-slate bg (#1a2125). RED is the rosy error color (5.7:1), not the hot-pink ANSI red (3.7:1).\n"
      "        CYAN=$'\\033[38;2;78;205;196m'       # Teal #4ECDC4\n"
      "        GREEN=$'\\033[38;2;143;188;143m'     # Sage accent #8FBC8F\n"
      "        YELLOW=$'\\033[38;2;243;156;18m'     # Amber #F39C12\n"
      "        RED=$'\\033[38;2;199;138;122m'       # Rose #c78a7a\n"
      "        PINK=$'\\033[38;2;155;89;182m'       # Purple #9B59B6\n"
      "        LAVENDER=$'\\033[38;2;102;217;239m'  # Sky blue #66D9EF\n"
      "        ;;\n"
      "    *)\n        echo \"statusline: unknown theme '$THEME'\" >&2\n")

# oh-my-posh: text insert keeps the file's formatting. lavender = fg on dark
# themes, = the pink value on light ones; os = the muted gray.
patch("ohmyposh/.config/ohmyposh/zen.omp.json",
      '        "red": "#d1383d"\n      }\n',
      '        "red": "#d1383d"\n      },\n'
      '      "forest_night": {\n        "os": "#6b7280",\n        "closer": "p:os",\n        "pink": "#9B59B6",\n'
      '        "lavender": "#c9d1d9",\n        "blue": "#4ECDC4",\n        "green": "#8FBC8F",\n'
      '        "peach": "#E67E22",\n        "red": "#E91E63"\n      }\n')

# tmux: the selector branch and the prefix-t menu row. session= is the pill color:
# @thm_green, or @thm_surface_1 when the green is too dark for the ink icon (light themes).
# The menu key is any letter the existing rows do not use.
patch("tmux/.config/tmux/tmux.conf",
      '       orng_light)       palette="$HOME/.config/tmux/themes/orng_light_tmux.conf";            session="##{E:@thm_surface_1}" ;; \\\n',
      '       orng_light)       palette="$HOME/.config/tmux/themes/orng_light_tmux.conf";            session="##{E:@thm_surface_1}" ;; \\\n'
      '       forest_night)     palette="$HOME/.config/tmux/themes/forest_night_tmux.conf";          session="##{E:@thm_green}" ;; \\\n')
patch("tmux/.config/tmux/tmux.conf",
      '\t"orng light"       o "run-shell \'~/.local/bin/theme-set orng_light\'"\n',
      '\t"orng light"       o "run-shell \'~/.local/bin/theme-set orng_light\'" \\\n'
      '\t"forest night"     F "run-shell \'~/.local/bin/theme-set forest_night\'"\n')

# Neovim: the name → colorscheme map, and a palette branch for the lualine bar.
# Without the branch the bar silently inherits catppuccin mocha's navy.
patch("nvim/.config/nvim/lua/config/theme.lua",
      '  orng_light       = { colorscheme = "orng-light",               background = "light" },\n',
      '  orng_light       = { colorscheme = "orng-light",               background = "light" },\n'
      '  forest_night     = { colorscheme = "forest-night",             background = "dark"  },\n')
patch("nvim/.config/nvim/lua/config/palette.lua",
      '  elseif scheme:match("^flexoki") then\n',
      '  elseif scheme:match("^forest%-night") then\n'
      '    return {\n'
      '      base = "#1a2125", mantle = "#14191c", crust = "#0d1113",\n'
      '      surface0 = "#222a30", surface1 = "#3a4a55", surface2 = "#4a5568",\n'
      '      text = "#c9d1d9", subtext0 = "#6b7280", subtext1 = "#a8b3bd", overlay0 = "#4a5568", overlay1 = "#6b7280",\n'
      '      blue = "#66D9EF", green = "#8FBC8F", red = "#c78a7a", yellow = "#F39C12",\n'
      '      mauve = "#9B59B6", teal = "#4ECDC4", pink = "#9B59B6", sky = "#4ECDC4",\n'
      '      bar_bg = "#222a30", -- one step up from base, so the statusline reads as a band\n'
      '    }\n'
      '  elseif scheme:match("^flexoki") then\n')
PY
```

The anchors are the current last arm of each file. When a later theme is the
last arm, `grep -n 'orng_light\|night_owl'` across those six files shows the
new one to anchor on.

## 5. Prove, switch on, commit

```bash
cd ~/dotfiles
bash -n scripts/.local/bin/theme-set && bash -n claude/.claude/commands/statusline-command.sh \
  && zsh -n zsh/.config/zsh/theme.zsh && jq -e '.palettes.list.forest_night' ohmyposh/.config/ohmyposh/zen.omp.json >/dev/null && echo syntax-ok
nvim --clean --headless "+set rtp+=$HOME/.config/nvim" "+colorscheme forest-night" \
  "+lua print(vim.g.colors_name, require('config.palette').get_palette().base)" +q   # → forest-night #1a2125
oh-my-posh cache clear
theme-set forest_night        # → "tmux:    reloaded (+env)"; "source-file failed" means the tmux.conf edit
printf '{"model":{"id":"claude-fable-5-1"},"workspace":{"current_dir":"/tmp"},"session_id":"x","context_window":{"context_window_size":200000,"total_input_tokens":1000,"total_output_tokens":0}}' \
  | bash claude/.claude/commands/statusline-command.sh | cat -v | head -1   # → the six escapes render, no "unknown theme"
zsh zsh/.config/zsh/tests/theme-sync.test.zsh | tail -1                     # → 0 failed
```

Leave the theme switched on — the user judges it by looking, and Ghostty takes
it on ⌘⇧, — and commit the theme alone; the working tree usually holds
unrelated edits, so name the paths:

```bash
git add scripts/.local/bin/theme-set zsh/.config/zsh/theme.zsh claude/.claude/commands/statusline-command.sh \
  ohmyposh/.config/ohmyposh/zen.omp.json tmux/.config/tmux/tmux.conf tmux/.config/tmux/themes/forest_night_tmux.conf \
  nvim/.config/nvim/lua/config/theme.lua nvim/.config/nvim/lua/config/palette.lua nvim/.config/nvim/colors/forest-night.lua \
  ghostty/.config/ghostty/themes/forest-night   # + lua/plugins/theme.lua and lazy-lock.json for a plugin scheme
git commit -m "theme: forest_night — <source>, <the one or two contrast calls you made>"
```

Done when `theme-set` reported every reload, the headless load printed the
scheme and its palette base, the commit holds only the theme's files, and the
report names the contrast calls and the switch is live. A rejected theme is
`git revert` of that one commit.
