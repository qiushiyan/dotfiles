# Migrating to a new MacBook Pro

This is the manual playbook that complements `scripts/bootstrap.sh` and
`scripts/list-secrets.sh`. Walk through the sections in order.

## Before you wipe the old Mac

- [ ] Push all local repo work, including any in-progress branches.
      `cd ~/Workspace && for d in */; do (cd "$d" && git status -sb); done`
      reveals dirty repos at a glance.
- [ ] Run the secrets audit:
      ```
      cd ~/dotfiles
      ./scripts/list-secrets.sh
      ```
      Inspect the printed table; confirm the `secrets-manifest.txt` file
      lists what you expect.
- [ ] Choose a transfer mechanism:
      - **rsync over LAN (recommended):** both Macs on same network,
        SSH from old to new (one-time `ssh-copy-id` to authorize).
      - **USB:** tar the listed paths, copy via external drive.
      - **AirDrop:** works for small files like `~/.secrets`, less ideal
        for `~/.ssh` directory permissions.
- [ ] Optional: kick off a Time Machine backup as a safety net.
- [ ] Do **not** sign out of iCloud on the old Mac until the new one is set up.

## Setting up the new Mac (macOS-level)

1. Setup Assistant → "Set up with iPhone" — handles Apple ID, Wi-Fi,
   and iCloud Keychain in one step.
2. Sign in to iCloud — the macOS Passwords app entries restore
   automatically.
3. **Enable FileVault** (System Settings → Privacy & Security → FileVault).
4. Optional: Time Machine to a new external drive.

## Restore secrets (BEFORE running bootstrap)

The bootstrap script clones the dotfiles repo via SSH (step 4),
which needs `~/.ssh/id_*` already in place.

1. Transfer the files listed in `secrets-manifest.txt`. Example over LAN:
   ```
   # On the old Mac:
   rsync -av --files-from=secrets-manifest.txt ~ qiushi@new-mbp.local:/Users/qiushi/
   ```
2. Fix permissions (rsync sometimes drops them):
   ```
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/id_* ~/.ssh/config* 2>/dev/null
   chmod 644 ~/.ssh/id_*.pub 2>/dev/null
   chmod 700 ~/.gnupg
   chmod 600 ~/.netrc ~/.npmrc ~/.secrets 2>/dev/null
   ```
3. Verify:
   ```
   ssh -T git@github.com           # should print "Hi qiushiyan!"
   gpg --list-secret-keys           # should list your key(s)
   aws sts get-caller-identity      # should print your account/user
   ```

## Run bootstrap

```
git clone git@github.com:qiushiyan/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

If a step fails, re-run just that step:
```
./scripts/bootstrap.sh brewfile
./scripts/bootstrap.sh node
```

The first run will pause at `xcode_clt` if Xcode CLT isn't installed —
follow the GUI prompt, then re-run the script.

## Workspace directory

Convention on the new machine: `~/dev/` (was `~/Workspace/` on the old
machine — the dotfiles don't reference either name).

```
mkdir -p ~/dev
```

Re-clone projects you actively want to work with into `~/dev/`. Treat
this as a fresh start — don't mass-rsync the entire old `~/Workspace`.

## Python setup

Why this section exists: macOS dev environments accumulate Python
installs from multiple sources (Homebrew, python.org `.pkg`, Apple's
stub, pyenv, conda) and editors get confused about which is "the"
Python. We dodge that by routing user-level Python through `uv`.

Brew installs `python@3.14` as a transitive dependency of other
formulae (apache-arrow, awscli, gdal, etc.) — that's fine; we just
don't use it directly.

```
# Install user-managed CPython (independent of Homebrew's transitive copy)
uv python install 3.14

# Pin 3.14 as the default for `uv venv` / `uv run`
uv python pin 3.14

# (Optional) install global CLI tools via `uv tool` instead of pipx
uv tool install ipython
uv tool install black
```

In Zed (or any IDE), set the Python interpreter to the uv-managed one:
```
$(uv python find 3.14)
```

Do NOT install python.org's `.pkg` — it sprays files into
`/Library/Frameworks/Python.framework` and `/usr/local/bin/`, both of
which are exactly what we just spent effort cleaning up on the old
machine.

## Re-auth (rather than copying state)

```
gh auth login
gcloud auth login && gcloud auth application-default login
```

## Manual installs (NOT in Brewfile)

Apps installed outside Homebrew. Add to this list as you encounter
others.

- **Ghostty** — download from <https://ghostty.org/>. (Used to be a
  Homebrew cask, removed from Brewfile because the existing install on
  the source machine wasn't brew-managed; using the official build is
  simpler.)
- **Logitech G Hub** — download from <https://www.logitech.com/en-us/software/g-hub.html>.

## App login pass

Walk through Dock / Launchpad and sign in:

- Slack
- Linear
- Raycast (it'll prompt for an account)
- Discord
- Postman
- MongoDB Compass
- Codex CLI
- Any IDE-like app: Zed, Ghostty (no login but verify settings).

iCloud Keychain pre-fills most of these.

## Verification checklist

Run from a fresh terminal after bootstrap completes.

- [ ] `cd ~/dotfiles && make install` reports clean (no Stow conflicts).
- [ ] `brew bundle check --file=~/dotfiles/Brewfile --no-upgrade` reports
      `dependencies are satisfied`.
- [ ] New zsh terminal opens with no errors loading modules.
- [ ] `git commit -S` succeeds (if you sign commits with GPG).
- [ ] `nvim` opens, plugins load (LazyVim shows lazy.nvim splash).
- [ ] `tmux` starts, status bar renders Catppuccin theme.
- [ ] `ghostty` launches with expected fonts (Iosevka, etc.).
- [ ] `node --version` prints LTS.
- [ ] `cargo --version` and `rustc --version` work.

## Files outside the repo (reference)

These are intentionally not committed and need manual transfer or
re-auth. `scripts/list-secrets.sh` enumerates them.

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
| `~/.config/gh/` | medium | re-auth via `gh auth login` |
| `~/.config/gcloud/` | medium | re-auth via `gcloud auth login` |
| iCloud Keychain | high | "Set up with iPhone" + iCloud sign-in |
| App logins (Slack/Linear/etc.) | medium | manual; Keychain pre-fills most |

## Old-machine cleanup leftover (do at your leisure)

The R version manager (`rim`) installed a binary into `/usr/local/bin/`
which requires `sudo` to remove. The Brewfile cleanup left it in place.
To purge fully on the old Mac:

```
sudo rm /usr/local/bin/rim
brew uninstall --cask --force rim
brew untap gaborcsardi/rim
```

This is purely cosmetic — the rim cask is no longer in `Brewfile`, so
it won't be installed on the new Mac.
