# Chrome shortcuts

Chrome is the default browser on the Macs here. Its keys keep the habits from
Arc: the address bar works as the command bar, and a few `ctrl` keys carry over.
Chrome cannot rebind its own commands, so every custom key lives outside Chrome,
in Karabiner, a macOS App Shortcut or an extension (§ Where a custom key lives).

## Menu

Custom keys:

| Key | Does | Lives in |
| --- | --- | --- |
| `ctrl+shift+p` | Focus the address bar | Karabiner, sends `cmd+l` |
| `cmd+shift+p` | Open Chrome Palette: actions, tabs, bookmarks, history | Extension |
| `cmd+n` | New tab | Karabiner, sends `cmd+t` |
| `cmd+d` | Duplicate the tab | Karabiner, sends `ctrl+d` |
| `ctrl+d` | Duplicate the tab | macOS App Shortcut |
| `cmd+backspace` | Close the tab | Karabiner, sends `cmd+w` |
| `ctrl+f` | Find in page | Karabiner, sends `cmd+f` |
| `ctrl+shift+i` | Open DevTools | Karabiner, sends `cmd+option+i` |
| `ctrl+shift+r` | Force reload | Karabiner, sends `cmd+shift+r` |

Chrome's own keys worth keeping in hand:

- **Address bar:** `cmd+l`
- **Close the tab:** `cmd+w`
- **Reopen the closed tab:** `cmd+shift+t`
- **Jump to a tab by position:** `cmd+1` to `cmd+8`; pinned tabs come first, so
  the low numbers reach the pinned sites
- **History:** `cmd+y`
- **Incognito window:** `cmd+shift+n`

A new normal window has no key: use **File > New Window** or `New Window` in
Chrome Palette.

## Where a custom key lives

Choose by what the key has to do:

- **Karabiner, `karabiner/.config/karabiner/karabiner.json`:** the key sends a
  key Chrome already has. It works beside the original key, so `cmd+l` and
  `ctrl+shift+p` both focus the address bar. Each rule is limited to Chrome by a
  `frontmost_application_if` condition. Karabiner reloads the file when it
  changes, and a machine gets the rules when it pulls this repository.
- **macOS App Shortcut, `step_macos_defaults` in `scripts/bootstrap.sh`:** the
  command has a menu item but no key, which is the case for **Tab > Duplicate
  Tab**, so Karabiner has nothing to send. Each machine holds its own copy in
  Chrome's preferences, and Chrome reads it when it starts.
- **Extension key, `chrome://extensions/shortcuts`:** the key opens an extension.
  Chrome Palette claims `cmd+shift+p` itself, and the extension reaches a machine
  through the Chrome profile's sync or the Web Store.

`cmd+d` chains Karabiner and the App Shortcut: Karabiner sends `ctrl+d`, and the
App Shortcut turns that into **Duplicate Tab**. Without the App Shortcut on a machine, `cmd+d` does
nothing useful there.

## Traps

- **`cmd+backspace` closes the tab inside text fields too.** Karabiner cannot see
  where the cursor is, so clearing a line in a chat box or form closes the tab,
  and a draft may not survive `cmd+shift+t`. To go back to `cmd+w`, delete the
  rule from `karabiner.json`.
- **An App Shortcut takes over the item's only key.** A menu item holds one
  shortcut, so binding `ctrl+shift+p` to **File > Open Location…** stops `cmd+l`
  working. Use Karabiner when the original key has to survive.
- **An App Shortcut needs a full restart of Chrome.** A closed window leaves the
  old process running. When a new shortcut does nothing, compare Chrome's start
  time with the time of the change, then check that the menu item shows the key:

  ```bash
  ps -axo lstart,comm | grep -E 'Google Chrome$'
  defaults read com.google.Chrome NSUserKeyEquivalents
  ```

- **Deleting the preference removes every App Shortcut for Chrome.** The command
  below takes the whole dictionary, not one entry:

  ```bash
  defaults delete com.google.Chrome NSUserKeyEquivalents
  ```

- **An item's title must match exactly,** including the `…` character in `Open
  Location…`.
- **`ctrl+d` next to Dictation's shortcut.** When Dictation's shortcut is "press
  Control twice", pressing `ctrl+d` twice quickly asks to enable Dictation. It is
  system state on each machine, off in **System Settings > Keyboard > Dictation >
  Shortcut** on the laptop and mini2. A new machine that shows the prompt needs
  the same setting.
- **`ctrl+f` and `ctrl+d` are also text-editing keys on a Mac,** for moving the
  cursor forward and deleting forward. `ctrl+f` loses that in Chrome's text
  fields, and `ctrl+d` should too.
- **`cmd+d` does not bookmark.** The star in the address bar does.
- **Karabiner only acts on keyboards it manages.** A keyboard set to `ignore` in
  `karabiner.json`'s `devices` keeps Chrome's own keys, so the Karabiner rows
  above do not apply to it.

## Pinned tabs and tab groups

Pinned tabs stand in for Arc's Favorites, and tab groups for its Spaces and
folders.

- **Pinned tabs per row:** no setting sets this. The count follows the width of
  the vertical tab sidebar, so drag the divider beside the page to change it.
  Narrowing the sidebar also cuts off the titles of normal tabs.
- **Ungrouping a tab group** keeps the tabs open on this machine and deletes the
  group on the account's other devices. Groups sync only where Chrome syncs
  history and tabs.
