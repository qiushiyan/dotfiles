# Palette extraction, per source

Reached from step 1 of `SKILL.md`; each block prints what the recipe needs.

## Zed theme (installed extension)

```bash
f=~/Library/Application\ Support/Zed/extensions/installed/aura-theme/themes/aura-dark.json
jq -r '.themes[] | select(.name=="Aura Dark") | .style
  | to_entries[] | select(.key | test("^(background|editor\\.(background|foreground|active_line)|terminal\\.|element\\.selected|border$|text)")) | "\(.key) \(.value)"' "$f"
jq -r '.themes[] | select(.name=="Aura Dark") | .style.syntax | to_entries[] | "\(.key) \(.value.color)"' "$f"
# → terminal.ansi.blue #82e2ff … / keyword #a277ff — an 8-digit value is #rrggbbaa: flatten it onto
#   background before use (alpha × color + (1-alpha) × bg per channel).
```

## VS Code theme (a repo)

Theme JSON is JSONC; strip comments and trailing commas, then read `colors` and
`tokenColors`:

```bash
node -e '
const fs=require("fs");let s=fs.readFileSync(process.argv[1],"utf8");
s=s.replace(/\/\*[\s\S]*?\*\//g,"").replace(/(^|[^:"])\/\/.*$/gm,"$1").replace(/,(\s*[}\]])/g,"$1");
const t=JSON.parse(s);
for(const [k,v] of Object.entries(t.colors||{})) if(/editor\.|terminal\.|selection|indentGuide|diffEditor|gitDecoration/.test(k)) console.log(k,v);
for(const tc of t.tokenColors||[]) console.log((tc.settings.foreground||"-").padEnd(9),(tc.settings.fontStyle||"").padEnd(12),"|",String(tc.scope).slice(0,120));
' themes/forest-night-color-theme.json
# → editor.background #1a2125 … / #F39C12   bold  | keyword.control.flow, …
```

An Omarchy theme's `colors.toml` beside it is already flat (`background`,
`foreground`, `red` … `bright_red` …, `selection`, `muted`); the VS Code file
adds the token map.

## Ghostty built-in, or a Neovim plugin

`/Applications/Ghostty.app/Contents/Resources/ghostty/themes/<Name>` holds the
16 palette lines plus bg/fg only. Surfaces and overlays (selection, elevated
panel, mantle, comment gray) come from the theme's upstream spec — a plugin's
`palette.lua` (`~/.local/share/nvim/lazy/<name>/lua/…/palette.lua` after
install), or the project's README palette table. Name that source in the
commit.
