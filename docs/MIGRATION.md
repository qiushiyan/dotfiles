# Migrating to a new MacBook Pro

The manual playbook that complements `scripts/bootstrap.sh` and
`scripts/list-secrets.sh`. Walk through the sections in order.

## 1. Before you wipe the old Mac

- [ ] Push all local repo work, including in-progress branches.
      `cd ~/Workspace && for d in */; do (cd "$d" && git status -sb); done`
      reveals dirty repos at a glance.
- [ ] Run the secrets audit:
      ```
      cd ~/dotfiles && ./scripts/list-secrets.sh
      ```
      Confirm `secrets-manifest.txt` lists what you expect.
- [ ] **Enable Remote Login** on the old Mac:
      System Settings → General → Sharing → toggle **Remote Login** on.
      You'll need this for the rsync transfers below *and* for any
      app-state sync later (Zed, Raycast, etc.). Note the `ssh` string
      shown in the same pane — that's your transfer target.
- [ ] Choose a transfer mechanism:
      - **rsync over LAN (recommended):** both Macs on same network.
      - **USB:** tar the listed paths, copy via external drive.
      - **AirDrop:** OK for `~/.secrets`, less ideal for `~/.ssh`
        directory permissions.
- [ ] Optional: kick off a Time Machine backup as a safety net.
- [ ] Do **not** sign out of iCloud on the old Mac until the new one is
      set up.

## 2. Set up the new Mac (macOS-level)

1. Setup Assistant → "Set up with iPhone" — handles Apple ID, Wi-Fi,
   and iCloud Keychain in one step.
2. Sign in to iCloud — macOS Passwords entries restore automatically.
3. **Enable FileVault** (System Settings → Privacy & Security → FileVault).
4. Optional: Time Machine to a new external drive.

## 3. Restore secrets (BEFORE running bootstrap)

The bootstrap script clones the dotfiles repo via SSH, which needs
`~/.ssh/id_*` already in place.

1. Transfer the files listed in `secrets-manifest.txt`. From the **old**
   Mac:
   ```
   # -r is required: --files-from cancels the default recursion that
   # -a normally provides.
   rsync -avr --files-from=secrets-manifest.txt ~ qiushi@<new-mac>.local:/Users/qiushi/
   ```
2. Fix permissions on the **new** Mac (rsync sometimes drops them):
   ```
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/id_* ~/.ssh/config* 2>/dev/null
   chmod 644 ~/.ssh/id_*.pub 2>/dev/null
   chmod 700 ~/.gnupg
   chmod 600 ~/.netrc ~/.npmrc ~/.secrets 2>/dev/null
   ```
3. Verify:
   ```
   ssh -T git@github.com               # "Hi qiushiyan!"
   ssh -T git@github.com-marswave      # "Hi yanqiushi-mw!"  (per-account alias)
   gpg --list-secret-keys              # lists your key(s)
   aws sts get-caller-identity         # prints your account/user
   ls ~/.gitconfig.{personal,marswave,cola}   # all three present
   ```

   The `.gitconfig.{personal,marswave,cola}` files are the per-identity
   includes referenced by `git/.gitconfig`'s `[includeIf "gitdir:~/dev/..."]`
   blocks. They live in `$HOME` (not the dotfiles repo, because it's
   public) and are pulled by the rsync above via `secrets-manifest.txt`.
   If a repo under `~/dev/marswave/` ever shows the wrong git identity
   (`git config user.email` returns the personal email), one of those
   files is missing or the `gitdir:` path doesn't match — see §5e.

## 4. Run bootstrap

```
git clone git@github.com:qiushiyan/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

Every step is **idempotent** — re-running the whole script (or a single
step like `./scripts/bootstrap.sh brewfile`) is safe.

### Things that will interrupt you

| Prompt | Why | What to do |
|---|---|---|
| GUI install dialog (Xcode CLT) | First-time only | Click through, then re-run `bootstrap.sh` |
| **sudo password** during `brew bundle` | `xquartz`, `font-sf-mono`, `font-sf-pro` install system-wide | Stay near the keyboard; if you fat-finger it 3×, the formula errors and `brew bundle` aborts. Re-run after. |
| `mongodb-community` failure | Mongo's brew formula breaks on each new macOS major | Currently commented out in `Brewfile`. If you actually need a local Mongo server, run it via Docker. |
| The `homebrew/cask` / `homebrew/core` "tap failed" lines | Deprecated taps; brew prints scary text but it's noise | Ignore (they're already removed from `Brewfile`). |

### What `step_thirdparty` installs

A few shell/tmux dependencies live outside Homebrew (the upstreams ship
as git repos, not formulae). The step git-clones them and, where
needed, runs the build:

| Repo | Destination | Used by |
|---|---|---|
| ohmyzsh/ohmyzsh | `~/.oh-my-zsh` | `.zshrc` (provides `compinit`/`compdef`) |
| zsh-users/zsh-syntax-highlighting | `~/zsh-syntax-highlighting` | `.zshrc` |
| zsh-users/zsh-autosuggestions | `~/.oh-my-zsh/custom/plugins/zsh-autosuggestions` | `.zshrc` plugins list |
| tmux-plugins/tpm | `~/.config/tmux/plugins/tpm` | `tmux.conf` plugin loader |
| jimeh/tmuxifier | `~/.config/tmux/plugins/tmuxifier` | `.zshrc` (`tmuxifier init`) |
| yetone/smart-suggestion | `~/.config/smart-suggestion` | `.zshrc` (Go binary built in-place) |

The step also runs tpm's `install_plugins` directly so the plugins
declared in `tmux.conf` (tmux-sensible, tmux-resurrect,
vim-tmux-navigator, catppuccin/tmux) are fetched without opening tmux
and hitting `prefix + I`.

### What `step_macos_defaults` sets

- **Natural scrolling off** (`com.apple.swipescrolldirection = false`).
  The single key controls **both** mouse and trackpad — the GUI's two
  toggles are aliases for it. Takes effect after logout/reboot.
- **Power management** via `pmset`: battery sleeps after 30 min (screen
  off at 10), on AC it never auto-sleeps (screen off at 20). This exists
  because stock macOS / a config profile once left `sleep=1` — the Mac
  napped after a single idle minute. **Needs sudo**, so this step prompts
  for your password (see the interrupt table above).

Add more `defaults write` / `pmset` lines to this step over time.

## 5. Post-bootstrap manual setup

### 5a. Workspace + Python + re-auths

```
mkdir -p ~/dev          # convention on this machine (was ~/Workspace before)

# Python — route user-level CPython through uv to dodge the multi-Python mess.
# Brew installs python@3.14 transitively (apache-arrow, awscli, gdal, …);
# we don't use it directly. Do NOT install python.org's .pkg.
uv python install 3.14
uv python pin 3.14
# Optional CLI tools:
# uv tool install ipython black

# Cloud auths (cheaper to redo than to copy state)
gh auth login
gcloud auth login && gcloud auth application-default login
```

In Zed (or any IDE), point the Python interpreter at `$(uv python find 3.14)`.

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

### 5e. Per-account git identities

`git/.gitconfig` ships with conditional includes that swap identity by
directory:

```
[includeIf "gitdir:~/dev/"]          path = ~/.gitconfig.personal
[includeIf "gitdir:~/dev/marswave/"] path = ~/.gitconfig.marswave
```

Inside `~/dev/marswave/...` the marswave block wins (it loads later).
The included files (`~/.gitconfig.personal`, `~/.gitconfig.marswave`,
`~/.gitconfig.cola`) are **not** in the dotfiles repo because the repo
is public and we don't want service-account names indexed. They live
in `$HOME` and migrate via the `secrets-manifest.txt` rsync (§3).

When adding a new identity:
1. Drop a new `~/.gitconfig.<name>` file with `[user]` + URL-rewrite block.
2. Add an `[includeIf]` to `git/.gitconfig` for the directory that
   should pick it up.
3. Add `.gitconfig.<name>` to `scripts/list-secrets.sh` `COPY_PATHS`
   (this regenerates `secrets-manifest.txt` next time it's run).
4. Make sure `~/.ssh/config` has a matching `Host github.com-<name>`
   alias pointing at the right `IdentityFile`.

To debug "wrong identity in this repo":
```
git config --show-origin user.email   # tells you which file set it
git config --get-all include.path     # lists which includes resolved
```

## 6. Verification checklist

Run from a fresh terminal after bootstrap completes.

- [ ] `cd ~/dotfiles && make install` reports clean (no Stow conflicts).
- [ ] `brew bundle check --file=~/dotfiles/Brewfile --no-upgrade` reports
      `dependencies are satisfied`.
- [ ] New zsh terminal opens with **no** missing-source errors.
- [ ] `git commit -S` succeeds (if you sign commits with GPG).
- [ ] `nvim` opens, plugins load (LazyVim splash).
- [ ] `tmux` starts, status bar renders Catppuccin theme.
- [ ] `ghostty` launches with expected fonts (Iosevka, etc.).
- [ ] `node --version` prints LTS, `cargo --version` and `rustc --version` work.
- [ ] `z <some old project>` jumps (zoxide is initialized).
- [ ] Natural scrolling matches your preference (logout/reboot first if not).
- [ ] `pmset -g custom` shows a sane system `sleep` (≠ 1 min) — battery
      30 / AC 0, per `step_macos_defaults`.

## Reference: files outside the repo

Not committed; need manual transfer or re-auth. `scripts/list-secrets.sh`
enumerates the secret ones.

| Path | Sensitive | Mechanism |
|---|---|---|
| `~/.secrets` | yes | rsync / scp |
| `~/.ssh/` (keys + `config.local`) | yes | rsync / scp |
| `~/.gnupg/` | yes | rsync / scp; verify with `gpg --list-secret-keys` |
| `~/.aws/credentials`, `~/.aws/config` | yes | rsync / scp |
| `~/.netrc` | yes | rsync / scp |
| `~/.npmrc` | yes | rsync / scp |
| `~/.kube/config` | medium | rsync / scp |
| `~/.docker/config.json` | medium | rsync / scp |
| `~/.gitconfig.{personal,marswave,cola}` | low (public keys + emails) | rsync / scp; see §5e |
| `~/.config/gh/` | medium | re-auth via `gh auth login` |
| `~/.config/gcloud/` | medium | re-auth via `gcloud auth login` |
| iCloud Keychain | high | "Set up with iPhone" + iCloud sign-in |
| App logins (Slack/Linear/etc.) | medium | manual; Keychain pre-fills most |
| `~/Library/Application Support/<App>/` | varies | per §5d (Zed worked example) |

## Reference: old-machine cleanup

The R version manager (`rim`) installed a binary into `/usr/local/bin/`
which requires `sudo` to remove. Brewfile cleanup left it in place. To
purge fully on the old Mac:

```
sudo rm /usr/local/bin/rim
brew uninstall --cask --force rim
brew untap gaborcsardi/rim
```

Cosmetic only — the rim cask is no longer in `Brewfile`.
