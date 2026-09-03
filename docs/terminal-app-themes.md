# Apple Terminal.app themes

Terminal.app profiles are **static snapshots**, not another live consumer of
`~/.config/terminal-theme`. Create one only when Terminal.app is explicitly in
scope; `theme-set` still owns the live Ghostty/tmux/Neovim/shell system described
in `docs/theming.md`.

## Create the profile

Use the finished Ghostty palette as the color source and clone an existing
Terminal profile for font, dimensions, and keyboard settings. The helper maps
all 16 ANSI slots plus background, foreground, cursor, selection, and bold:

```bash
cd ~/dotfiles
PROFILE='Tailwind Light'
swift .claude/skills/add-theme/scripts/macos-terminal-profile.swift \
  --ghostty ghostty/.config/ghostty/themes/tailwind-light-contrast \
  --name "$PROFILE" \
  --bold '#1447e6' \
  --template 'Flexoki Light' \
  --output "terminal/.config/terminal-profiles/$PROFILE.terminal"
plutil -lint "terminal/.config/terminal-profiles/$PROFILE.terminal"
stow -R terminal
```

`--template` is optional and otherwise uses Terminal.app's current default.
Keep `--bold` aligned with the theme's `bold-color` arm in `theme-set`.

The helper deliberately archives `NSColor(calibratedRed:...)`: this is the
compact representation Terminal uses. `NSColor(srgbRed:...)` embeds an ICC
profile in every color and turned the 21-color Tailwind profile from about
9.5 KB into 106 KB without improving the result.

## Install and use it

Opening a `.terminal` file imports it and opens a window, but does not reliably
make it the default. Set both preference keys after the profile appears:

```bash
PROFILE='Tailwind Light'
open -a Terminal "$HOME/.config/terminal-profiles/$PROFILE.terminal"
for attempt in {1..20}; do
  defaults export com.apple.Terminal - \
    | plutil -extract "Window Settings.$PROFILE.name" raw -o - - 2>/dev/null \
    | rg -qx "$PROFILE" && break
  sleep 0.5
done
if defaults export com.apple.Terminal - \
  | plutil -extract "Window Settings.$PROFILE.name" raw -o - - 2>/dev/null \
  | rg -qx "$PROFILE"; then
  defaults write com.apple.Terminal 'Default Window Settings' -string "$PROFILE"
  defaults write com.apple.Terminal 'Startup Window Settings' -string "$PROFILE"
else
  print -ru2 "Terminal.app did not import $PROFILE"
fi
```

Verify the imported profile, both defaults, and the new front window:

```bash
defaults export com.apple.Terminal - \
  | plutil -extract "Window Settings.$PROFILE.name" raw -o - -
defaults read com.apple.Terminal 'Default Window Settings'
defaults read com.apple.Terminal 'Startup Window Settings'
osascript -e 'tell application "Terminal" to get name of current settings of selected tab of front window'
```

Commit the `.terminal` file with the other theme files when Terminal.app was
part of the original port; for a later opt-in, commit it alone. Existing windows
do not change when the default changes—the window opened by the import is the
visual check.
