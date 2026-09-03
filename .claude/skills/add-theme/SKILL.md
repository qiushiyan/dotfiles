---
name: add-theme
description: Port a color theme into the terminal theme system — one palette per tool, proven with theme-set, switched on, committed.
disable-model-invocation: true
---

# Add a terminal theme

One name in `~/.config/terminal-theme`; every terminal-side tool maps it to
its own hand-tuned palette. Nine surfaces: three new files (Ghostty, tmux,
Neovim) and six shared files that each gain an arm. Done when
`theme-set <name>` reports every reload, the theme is live for the user to
judge, and one commit holds exactly its files. A tool that does not pick the
switch up → `docs/theming.md`.

Copy the nearest **exemplar**: `git show 94f49f9` is a complete dark port
(`forest_night`, hand-rolled Neovim scheme); `night_owl` (dark, plugin scheme)
and `orng_light` (light) are the others — `grep -rn orng_light` finds every arm.
Every value stays in-family — the theme's own tokens — and
where a token fails contrast on the theme's background, take a darker or
lighter hue from the same theme and say which in the comment beside it.

## 1. Get the palette

Needed: background, foreground, the 16 ANSI colors, the accent, two or three
surface elevations (selection, an elevated panel, a darker mantle), and, for
a hand-rolled Neovim scheme, the syntax token map. The extraction per source is
in [`sources.md`](sources.md).

| source | where it is |
|---|---|
| Zed theme (installed extension) | `~/Library/Application Support/Zed/extensions/installed/<ext>/themes/*.json` — `.themes[].style` has `background`, `terminal.ansi.*`, `syntax.*`; surface values are `#rrggbbaa`, flattened onto the background |
| Ghostty built-in | `/Applications/Ghostty.app/Contents/Resources/ghostty/themes/<Name>` — 16 palette lines plus bg/fg; surfaces come from the upstream spec |
| a repo (Omarchy `colors.toml`, a VS Code theme) | `git clone --depth 1` into the scratchpad; the VS Code JSON is JSONC |

## 2. Name it

`<name>` is snake_case: `forest_night`. Files use dashes — Ghostty
`themes/forest-night`, Neovim `colors/forest-night.lua`, colorscheme
`forest-night` — except tmux, `themes/forest_night_tmux.conf`. A Ghostty
built-in keeps its spaced name in theme-set (`theme = Rose Pine Dawn`).

## 3. The three new files

- **Ghostty** `ghostty/.config/ghostty/themes/<name-dashed>` — 16 `palette =
  N=#hex` lines plus `background`, `foreground`, `cursor-color`,
  `selection-background`, `selection-foreground`. Slot 8 (bright black) is the
  zsh autosuggestion color and must read on the background (≈4:1). A Ghostty
  built-in needs no file.
- **tmux** `tmux/.config/tmux/themes/<name>_tmux.conf` — copy the exemplar;
  its header names each slot and the decisions (the two badge accents, the
  session pill, the active chip one step lighter than the inactive one).
- **Neovim**, one of two:
  - hand-rolled `nvim/.config/nvim/colors/<name-dashed>.lua` — copy the
    exemplar group for group and map the source's token colors onto it
    (keywords, functions, strings, properties, types, constants, comments;
    diff and diagnostic tints blended onto the background).
  - a plugin — `grep -n '<owner/repo>' nvim/.config/nvim/lua/plugins/theme.lua`
    first: a spec may already exist (`rose-pine/neovim` does, disabled); edit
    that one (drop its `enabled = false`) rather than adding a second, since
    lazy.nvim merges fragments of one plugin. The spec is the `night-owl.nvim`
    entry's shape — `priority = 1000`, `lazy = theme.name ~= "<name>"` — plus
    `name = "<name>"` as the catppuccin entry has, so the lock file keys it
    predictably. Install with `nvim --headless "+Lazy! install" +qa`; the
    colorscheme name is what the plugin registers: `ls
    ~/.local/share/nvim/lazy/<name>/colors`.

## 4. Patch the six shared files

One script, one run; it stops before writing if any anchor is not exactly
once in its file. The anchors are structural (the `*)` fallthroughs, each
list's closing) and survive every port, so a port replaces the NAME line, the
colors and the comments, nothing else. Light and dark differ in five places:

| | dark | light |
|---|---|---|
| theme.lua `background` (`BG` in the script) | `"dark"` | `"light"` |
| theme-set `bold-color` | warmer and brighter than fg — the bright yellow (`#FFB74D`) | deeper and more saturated than fg (orng `#c94d24`) |
| zsh arm | `LSCOLORS='Gxfxcx…'`, `di=1;36`, `fg=8`, `+dark-mode` / `dark` | `LSCOLORS='exfxcx…'`, `di=34`, `fg=242`, `+light-mode` / `light` — copy `orng_light)` whole |
| oh-my-posh `lavender` | the fg | the `pink` value |
| tmux `session=` (the pill) | `@thm_green` | `@thm_surface_1` — the green is too dark for the ink icon |

```bash
cd ~/dotfiles && python3 - <<'PY'
import pathlib, re, sys
NAME, DASHED, LABEL, KEY, BG = "forest_night", "forest-night", "forest night", "F", "dark"   # KEY: a letter no menu row uses yet
LUA_PAT = DASHED.replace("-", "%-")

def patch(path, old, new):
    p = pathlib.Path(path); s = p.read_text()
    if s.count(old) != 1: sys.exit(f"{path}: anchor found {s.count(old)}x:\n{old!r}")
    p.write_text(s.replace(old, new)); print("patched", path)

# theme-set: the THEMES array and the ghostty block (theme = a themes/ file, or a built-in's spaced name)
p = pathlib.Path("scripts/.local/bin/theme-set"); s = p.read_text()
s2 = re.sub(r"^(THEMES=\(.*)\)$", rf"\1 {NAME})", s, count=1, flags=re.M)
assert s2 != s, "THEMES line"; p.write_text(s2); print("patched THEMES")
patch("scripts/.local/bin/theme-set", "  esac\n}\n",
      f"    {NAME})     printf 'theme = {DASHED}\\nbold-color = #FFB74D\\n' ;;\n  esac\n}}\n")

# zsh: the arm before the `*)` fallthrough
patch("zsh/.config/zsh/theme.zsh", "    *)\n        print -ru2",
      f"    {NAME})\n"
      "        # Blue-slate bg (#1a2125): bold/bright dir for emphasis, same as the other dark arms.\n"
      "        export LSCOLORS='Gxfxcxdxbxegedabagacad'\n"
      "        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'\n"
      "        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'\n"
      "        export DELTA_FEATURES='+dark-mode'\n"
      "        export DFT_BACKGROUND='dark'\n"
      "        ;;\n"
      "    *)\n        print -ru2")

# Claude statusline: the arm before the `*)` fallthrough; decimal RGB from hex: printf '%d;%d;%d' 0x4E 0xCD 0xC4
patch("claude/.claude/commands/statusline-command.sh", "    *)\n        echo \"statusline: unknown",
      f"    {NAME})\n"
      "        # Blue-slate bg (#1a2125). RED is the rosy error color (5.7:1), not the hot-pink ANSI red (3.7:1).\n"
      "        CYAN=$'\\033[38;2;78;205;196m'       # Teal #4ECDC4\n"
      "        GREEN=$'\\033[38;2;143;188;143m'     # Sage accent #8FBC8F\n"
      "        YELLOW=$'\\033[38;2;243;156;18m'     # Amber #F39C12\n"
      "        RED=$'\\033[38;2;199;138;122m'       # Rose #c78a7a\n"
      "        PINK=$'\\033[38;2;155;89;182m'       # Purple #9B59B6\n"
      "        LAVENDER=$'\\033[38;2;102;217;239m'  # Sky blue #66D9EF\n"
      "        ;;\n"
      "    *)\n        echo \"statusline: unknown")

# oh-my-posh: appended as the last palette (text insert keeps the file's formatting)
patch("ohmyposh/.config/ohmyposh/zen.omp.json", "\n      }\n    }\n",
      "\n      },\n"
      f'      "{NAME}": {{\n        "os": "#6b7280",\n        "closer": "p:os",\n        "pink": "#9B59B6",\n'
      '        "lavender": "#c9d1d9",\n        "blue": "#4ECDC4",\n        "green": "#8FBC8F",\n'
      '        "peach": "#E67E22",\n        "red": "#E91E63"\n      }\n    }\n')

# tmux: the selector branch before the `*)` default, and a row appended to the prefix-t menu
patch("tmux/.config/tmux/tmux.conf", "       *)                palette=",
      f'       {NAME}) palette="$HOME/.config/tmux/themes/{NAME}_tmux.conf"; session="##{{E:@thm_green}}" ;; \\\n'
      "       *)                palette=")
p = pathlib.Path("tmux/.config/tmux/tmux.conf"); lines = p.read_text().split("\n")
i = next(k for k, l in enumerate(lines) if "bind t display-menu" in l)
while lines[i].rstrip().endswith("\\"): i += 1                       # the last menu row has no trailing backslash
assert f' {KEY} "' not in "\n".join(lines[i-12:i+1]), f"menu key {KEY} is taken"
lines[i] += " \\"; lines.insert(i + 1, f'\t"{LABEL}" {KEY} "run-shell \'~/.local/bin/theme-set {NAME}\'"')
p.write_text("\n".join(lines)); print("patched menu row")

# Neovim: the name → colorscheme map, and a palette branch for the lualine bar
patch("nvim/.config/nvim/lua/config/theme.lua", "\n}\n\nM.name = resolve()",
      f'\n  {NAME} = {{ colorscheme = "{DASHED}", background = "{BG}" }},\n}}\n\nM.name = resolve()')
patch("nvim/.config/nvim/lua/config/palette.lua", '  elseif scheme:match("^flexoki") then',
      f'  elseif scheme:match("^{LUA_PAT}") then\n'
      '    return {\n'
      '      base = "#1a2125", mantle = "#14191c", crust = "#0d1113",\n'
      '      surface0 = "#222a30", surface1 = "#3a4a55", surface2 = "#4a5568",\n'
      '      text = "#c9d1d9", subtext0 = "#6b7280", subtext1 = "#a8b3bd", overlay0 = "#4a5568", overlay1 = "#6b7280",\n'
      '      blue = "#66D9EF", green = "#8FBC8F", red = "#c78a7a", yellow = "#F39C12",\n'
      '      mauve = "#9B59B6", teal = "#4ECDC4", pink = "#9B59B6", sky = "#4ECDC4",\n'
      '      bar_bg = "#222a30", -- one step up from base, so the statusline reads as a band\n'
      '    }\n'
      '  elseif scheme:match("^flexoki") then')
PY
```

## 5. Prove, switch on, commit

```bash
cd ~/dotfiles; NAME=forest_night; DASHED=forest-night
bash -n scripts/.local/bin/theme-set && bash -n claude/.claude/commands/statusline-command.sh \
  && zsh -n zsh/.config/zsh/theme.zsh && jq -e ".palettes.list.$NAME" ohmyposh/.config/ohmyposh/zen.omp.json >/dev/null && echo syntax-ok
# hand-rolled scheme: --clean sees colors/; a plugin scheme needs the full config so lazy is on the rtp
nvim --clean --headless "+set rtp+=$HOME/.config/nvim" "+colorscheme $DASHED" \
  "+lua print(vim.g.colors_name, require('config.palette').get_palette().base)" +q     # → forest-night #1a2125
nvim --headless "+colorscheme $DASHED" "+lua print(vim.g.colors_name, require('config.palette').get_palette().base)" +qa
oh-my-posh cache clear
theme-set $NAME               # → "tmux:    reloaded (+env)"; "source-file failed" points at the tmux.conf edit
printf '{"model":{"id":"claude-fable-5-1"},"workspace":{"current_dir":"/tmp"},"session_id":"x","context_window":{"context_window_size":200000,"total_input_tokens":1000,"total_output_tokens":0}}' \
  | bash claude/.claude/commands/statusline-command.sh | cat -v | head -1     # → six escapes render, no "unknown theme"
```

Leave the theme switched on — the user judges it by looking, and Ghostty takes
it on ⌘⇧, — and commit the theme alone, by path, since the working tree
usually holds unrelated edits:

```bash
git add scripts/.local/bin/theme-set zsh/.config/zsh/theme.zsh claude/.claude/commands/statusline-command.sh \
  ohmyposh/.config/ohmyposh/zen.omp.json tmux/.config/tmux/tmux.conf tmux/.config/tmux/themes/${NAME}_tmux.conf \
  nvim/.config/nvim/lua/config/theme.lua nvim/.config/nvim/lua/config/palette.lua \
  nvim/.config/nvim/colors/$DASHED.lua ghostty/.config/ghostty/themes/$DASHED
# plugin scheme: lua/plugins/theme.lua instead of colors/, and only the theme's lock hunk:
#   git add -p nvim/.config/nvim/lazy-lock.json; a Ghostty built-in adds no themes/ file
git commit -m "theme: $NAME — <source>, <the contrast calls made>"
```

The report names the source and the contrast calls. A rejected theme is
`git revert` of that one commit.

## Optional: Apple Terminal.app

Terminal.app is not one of the nine live-switched surfaces: its profiles are
static imports. When the user explicitly asks for Terminal.app, create and
activate a matching `.terminal` profile after the main port. Follow
[`docs/terminal-app-themes.md`](../../../docs/terminal-app-themes.md); its helper
reuses the Ghostty palette, preserves an existing profile's font/layout settings,
and avoids hand-writing archived `NSColor` data. Include the profile in the theme
commit when it was requested up front, or commit it alone when added later.
