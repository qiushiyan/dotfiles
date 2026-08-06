# Migrating app state

Satellite of `docs/MIGRATION.md` §5. The main checklist gets a new machine to a
working configured state; this covers the part the repo cannot do for you —
apps that aren't in the `Brewfile`, permissions and sign-ins that only exist in
system settings, and the app state living outside `~/.config` that a fresh
install starts without.

Work through it after §5a, before §5e.

### 5b. Apps NOT in the Brewfile

Manual downloads, by intent:

- **Ghostty** — <https://ghostty.org/>. Cask was removed because the
  source machine's install wasn't brew-managed.
- **Logitech G Hub** — <https://www.logitech.com/en-us/software/g-hub.html>.
- **Karabiner-Elements** — currently commented out in `Brewfile`
  (`# cask "karabiner-elements"`). Install the cask manually if you
  use it — the brew install + driver kext approval flow is finicky
  enough that a manual download from <https://karabiner-elements.pqrs.org/>
  is usually less painful.

### 5c. App permissions, sign-ins, defaults to undo

Most apps have first-launch onboarding — don't try to enumerate every
checkbox. Just be aware of the categories:

- **Apps that need Accessibility / Input Monitoring**: Karabiner-Elements,
  Logitech G Hub, Raycast, Rectangle. First launch pops a system dialog
  that links straight to the right pane in System Settings → Privacy &
  Security. Approve, then quit & relaunch the app.
- **Apps that just need a sign-in** (iCloud Keychain pre-fills most):
  Slack, Linear, Discord, Postman, MongoDB Compass, Codex, Raycast,
  Zed (for Zed AI). Walk the Dock/Launchpad and log in.
- **Default macOS shortcut conflicts** to disable so they stop hijacking
  your Raycast/Zed/etc. binds:
  - System Settings → Keyboard → **Keyboard Shortcuts…** button →
    Services → Text → uncheck **Convert Text to Simplified Chinese**
    (`⌃⌥⇧⌘C`) and **Convert Text to Traditional Chinese** (`⌃⌥⇧⌘T`).
  - Same panel, **Mission Control** → review the workspace shortcuts
    if you've remapped them via Karabiner.

### 5d. Sync app state from the old Mac (lessons learned)

> **Trap**: just because a config dir lives under `~/.config/<app>/`
> doesn't mean it's part of this dotfiles repo. On the old Mac, several
> dirs (e.g. `~/.config/zed`) were **real directories**, not symlinks
> to the dotfiles repo — meaning the committed copy was stale relative
> to the live config. Always `ls -la ~/.config/` on the old Mac and
> diff the live file against the dotfiles version before assuming
> stow gave you the right state.

#### Pattern for app-state rsync

1. Enable Remote Login on the old Mac (§1).
2. Authorize the new Mac for password-less SSH:
   ```
   ssh-copy-id qiushi@<old-mac>.local   # type old Mac's account password once
   ```
   Even if `~/.ssh/` was rsynced over (so both Macs share the same
   *private* key), the old Mac still needs the new Mac's *public* key
   in its `authorized_keys`.
3. Quit the app on the new Mac before copying its sqlite-backed state,
   or you'll corrupt the DB.
4. Use rsync with **`-s` (protect-args)** and **absolute paths**:
   ```
   # -s preserves spaces in remote paths (Application Support has one),
   # but it ALSO disables ~ expansion — so spell out /Users/qiushi/...
   rsync -avs qiushi@<old-mac>.local:"/Users/qiushi/Library/Application Support/<App>/" \
              "$HOME/Library/Application Support/<App>/"
   ```
5. Skip the bloat: language-server runtimes, downloaded Node, crash
   dumps, prettier caches. Most apps re-download them.

#### Worked example: Zed

Source: `~/Library/Application Support/Zed/` on the old Mac (~12GB,
mostly bloat).

| Subdir | Copy? | Why |
|---|---|---|
| `db/` | yes | Recent projects + window state (sqlite) |
| `threads/` | yes | Zed AI conversation history |
| `extensions/` | yes (~574MB) | 47 extensions; faster than re-installing |
| `external_agents/` | optional | State for in-Zed Claude Code/Codex — only if you used them |
| `node/`, `languages/`, `debug_adapters/`, `prettier/`, `copilot/`, `hang_traces/` | no | Re-downloaded automatically; copilot just re-auth |

Also copy local theme JSONs (these aren't extensions):
```
rsync -avs qiushi@<old-mac>.local:"/Users/qiushi/.config/zed/themes/" \
           "$HOME/.config/zed/themes/"
```

If your dotfiles' `settings.json` is older than the live one on the old
Mac, diff first then overwrite:
```
ssh qiushi@<old-mac>.local 'cat ~/.config/zed/settings.json' > /tmp/old.json
diff -u ~/dotfiles/zed/.config/zed/settings.json /tmp/old.json
cp /tmp/old.json ~/dotfiles/zed/.config/zed/settings.json
```

#### Other apps where the same pattern likely applies

Worth checking on the old Mac before declaring migration done:

- **Raycast** — Settings → Account → Cloud Sync handles most state. If
  Cloud Sync was off, rsync `~/Library/Application Support/com.raycast.macos/`
  and `~/Library/Preferences/com.raycast.macos.plist` (with Raycast quit).
- **Karabiner-Elements** — `~/.config/karabiner/` *is* in the dotfiles
  repo, but verify the live file matches before trusting it.
- **Ghostty** — `~/.config/ghostty/` is in the dotfiles repo.
- **Tmux/sesh sessions** — not migrated; just recreate as needed.

