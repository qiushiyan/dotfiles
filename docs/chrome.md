# Chrome shortcuts

Chrome is becoming the primary browser in place of Arc (§ Moving from Arc). Its
keys keep the habits from Arc: the address bar works as the command bar, and a
few `ctrl` keys carry over. Chrome cannot rebind its own commands, so every custom
key lives outside Chrome, in Karabiner, a macOS App Shortcut or an extension
(§ Where a custom key lives).

## Moving from Arc

The move is under way, so both browsers stay installed and either may be in use
on any machine; each machine's default browser is its own setting. Outlets report
that Arc stops working on 2026-12-22, which would bound this period.

- **A missing Arc habit is work to port.** More settings are expected to come
  across, so add a key to this doc's menu when one does. Arc's custom keys are in
  `~/Library/Application Support/Arc/StorableKeyBindings.json`, and its Favorites
  and pinned tabs in `StorableSidebar.json` beside it.
- **A password saved in Arc stays in Arc.** Arc's account does not sync to Chrome.
  To move one, export a CSV from Arc and import it at
  `chrome://password-manager/settings` on the same machine, choose the Google
  account if asked, and delete the CSV.
- **Chrome's rules do not touch Arc.** Every Karabiner rule here is limited to
  Chrome, so Arc keeps its own keys while both are in use.

When the move finishes, `cask "arc"` leaves the `Brewfile` and this section goes.

## Menu

Custom keys:

| Key | Does | Lives in |
| --- | --- | --- |
| `ctrl+shift+p` | Focus the address bar | Karabiner, sends `cmd+l` |
| `cmd+shift+p` | Open Chrome Palette: actions, tabs, bookmarks, history | Extension |
| `cmd+n` | New tab after the current one | Karabiner, sends `ctrl+t` |
| `ctrl+t` | New tab after the current one | macOS App Shortcut |
| `cmd+d` | Duplicate the tab | Karabiner, sends `ctrl+d` |
| `ctrl+d` | Duplicate the tab | macOS App Shortcut |
| `cmd+backspace` | Close the tab | Karabiner, sends `cmd+w` |
| `ctrl+f` | Find in page | Karabiner, sends `cmd+f` |
| `ctrl+shift+i` | Open DevTools | Karabiner, sends `cmd+option+i` |
| `ctrl+shift+r` | Force reload | Karabiner, sends `cmd+shift+r` |

Chrome's own keys worth keeping in hand:

- **Address bar:** `cmd+l`
- **New tab at the end of the strip:** `cmd+t`
- **Back and forward:** `cmd+left` and `cmd+right`, or `cmd+[` and `cmd+]`. The
  page sees the arrow keys first, so in a text field they move the cursor, and a
  Karabiner rule would lose that
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
  Tab** and **Tab > New Tab Below**, so Karabiner has nothing to send. Each machine holds its own copy in
  Chrome's preferences, and Chrome reads it when it starts.
- **Extension key, `chrome://extensions/shortcuts`:** the key opens an extension.
  Chrome Palette claims `cmd+shift+p` itself, and the extension reaches a machine
  through the Chrome profile's sync or the Web Store.

`cmd+d` and `cmd+n` chain Karabiner and the App Shortcut: Karabiner sends
`ctrl+d` or `ctrl+t`, and the App Shortcut turns that into **Duplicate Tab** or
**New Tab Below**. Without the App Shortcut on a machine, the `cmd` key does
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
  Location…`. Some titles follow the tab layout: with horizontal tabs, **New Tab
  Below** reads **New Tab to the Right**, so `bootstrap.sh` binds both.
- **`ctrl+d` next to Dictation's shortcut.** When Dictation's shortcut is "press
  Control twice", pressing `ctrl+d` twice quickly asks to enable Dictation. It is
  system state on each machine, off in **System Settings > Keyboard > Dictation >
  Shortcut** on the laptop and mini2. A new machine that shows the prompt needs
  the same setting.
- **`ctrl+f`, `ctrl+d` and `ctrl+t` are also text-editing keys on a Mac,** for
  moving the cursor forward, deleting forward and swapping the characters around
  the cursor. `ctrl+f` loses that in Chrome's text fields, and `ctrl+d` and
  `ctrl+t` should too.
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
