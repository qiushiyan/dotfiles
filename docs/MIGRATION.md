# Migrating to a new MacBook Pro

The manual playbook that complements `scripts/bootstrap.sh` and
`scripts/list-secrets.sh`. Walk through the sections in order.

## 1. Before you wipe the old Mac

- [ ] Push all local repo work, including in-progress branches.
      `cd ~/dev && for d in */; do (cd "$d" && git status -sb); done`
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
| `qiushiyan/local` tap fails / `tmux-popupfix` not found | That tap is local-only (no remote) — it carries the patched tmux formula | `brew tap-new qiushiyan/local`, copy `docs/tmux-popupfix.rb` to the tap's `Formula/`, re-run → `docs/tmux-popup-patch.md` |
| `font-sarasa-gothic` takes a while and lands **793 MB** | It ships one `Sarasa-SuperTTC.ttc` holding 480 faces — SC/TC/J/K × Mono/Term/Fixed/Gothic/UI × every weight — and only `Sarasa Term SC` is used | Let it. Splitting it out means hand-downloading the SC-only archive and leaving Homebrew's management, which is the worse trade → `docs/ghostty-fonts.md` |

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
mkdir -p ~/dev          # project checkouts live here; ~/dev/.worktrees beside them

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

### 5b–5d. Apps, permissions, and app state

Apps outside the `Brewfile`, the permissions and sign-ins to re-grant, and the
app state that has to be copied off the old Mac by hand — including the trap
that a `~/.config/<app>/` directory is not necessarily managed by this repo:
`docs/migration-app-state.md`.

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
- [ ] `tmux` starts, status bar themed per `~/.config/terminal-theme`.
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

Casks that drop a binary into `/usr/local/bin/` survive `brew uninstall` and
Brewfile cleanup, because removing it needs `sudo`. The R version manager
`rim` was the case that surfaced this — purging it fully took `sudo rm
/usr/local/bin/rim` alongside the `brew uninstall --cask --force` and
`brew untap`. Worth checking for any cask you retire.
