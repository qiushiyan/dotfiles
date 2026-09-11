# Codex themes

`*.tmTheme` files provide terminal CLI syntax palettes selected by `[tui].theme`
in `~/.codex/config.toml`.

`*.codex-theme` files are desktop appearance share strings. To apply Token
Meridian Light, copy the complete contents of `token-meridian-light.codex-theme`,
open Settings → Appearance → Light theme → Import, paste the string, and choose
Import theme. Set the appearance mode to Light.

The Meridian desktop port uses the local Token palette at upstream revision
`11be57ef6913`, with its original background, foreground, accent, and Git colors.
Its license is in `token-meridian-light.LICENSE`. Contrast uses the app's default
light value, 45; opaque windows preserve the background color. Fonts use the app
defaults. The desktop importer accepts built-in code theme IDs only, so code
highlighting uses Codex. It does not load the terminal's `.tmTheme` files.

Import format and fields were checked against the installed app's theme parser;
importing and visual appearance still require verification in the app.
