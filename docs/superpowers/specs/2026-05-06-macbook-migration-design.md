# Migrating dotfiles + dev environment to a new MacBook Pro (M5)

**Date:** 2026-05-06
**Status:** Approved (brainstorming complete; ready for implementation plan)

## Context

The user is moving from this MacBook to a new MBP (M5, 48GB RAM, 1TB).
The dotfiles repo here is Stow-managed: each top-level package symlinks
into `$HOME` via `make install`. In theory, the dotfiles can be migrated
verbatim. In practice the user wants to:

- Use the migration as an opportunity to shed accumulated cruft.
- Avoid bringing forward casks/extensions they no longer use (e.g. VS
  Code — they will use Zed only on the new machine).
- Have *some* automation for the mechanical steps (Homebrew, Stow,
  toolchain), without pretending to automate things that need judgment.
- Keep secrets transfer manual but documented.

## Goal

Produce three things:

1. A **cleaned-up Brewfile** committed to the current repo, so the new
   machine starts from a curated baseline.
2. A small **bootstrap script** for the new MBP that handles the
   deterministic installation steps.
3. A **migration playbook** in markdown for everything that can't or
   shouldn't be scripted (secrets, manual app installs, app re-logins,
   verification).

Apple Migration Assistant is *not* required, but is acceptable as a
bonus to preserve macOS Keychain / app logins. The new machine is
Apple-Silicon, same as the old one, so the standard "don't use
Migration Assistant when going Intel→AS" caveat doesn't apply.

## Scope

**In scope**

- Editing `Brewfile` to remove dead, unwanted, and editor-specific
  entries; add section comments for legibility.
- Creating `scripts/bootstrap.sh` and `scripts/list-secrets.sh`.
- Creating `docs/MIGRATION.md`.
- Documenting which files outside the dotfiles repo need manual
  transfer, and the recommended transfer mechanism.

**Out of scope**

- Changing how Stow packages are organized.
- Reproducing macOS `defaults write` system-tweaks (can be a follow-up
  if the user wants).
- 1Password CLI workflows (not used).
- Migrating Xcode simulator data, browser profiles, Notes, Photos, etc.
  — those flow through iCloud or Migration Assistant, neither is the
  bootstrap script's problem.
- 100% automation. Manual steps are acceptable.

## Deliverables

```
dotfiles/
├── Brewfile                           # MODIFIED
├── scripts/
│   ├── bootstrap.sh                   # NEW
│   └── list-secrets.sh                # NEW
└── docs/
    └── MIGRATION.md                   # NEW
```

No changes to the existing Stow packages.

## Brewfile cleanup

### Hard removals

| Entry | Reason |
|---|---|
| `cask "fig"` | Discontinued (acquired by AWS, became CodeWhisperer). |
| `cask "hyper"` | Replaced by Ghostty. |
| `cask "logitech-g-hub"` | User will install manually outside Brew (documented in MIGRATION.md). |
| `cask "tonisives/tap/ovim"` + `tap "tonisives/tap"` | Unused. |
| `cask "pgadmin4"` | Unused. |
| `cask "rstudio"`, `cask "gaborcsardi/rim/rim"`, `tap "gaborcsardi/rim"` | R toolchain no longer needed. |
| `tap "learlab/itell-cli"` + `brew "learlab/itell-cli/itell"` | Unused. |
| `tap "heroku/brew"` | Unused. |
| **All `vscode "..."` entries (lines 156–311)** | User is going Zed-only on new machine. |

### Kept as-is

`cask "discord"` — explicitly retained.

### Reorganization

After removals, group remaining entries with section comments. Target
structure:

```
# === Taps ===
# === Build dependencies ===     (libpng, openssl@3, gcc, libomp, ...)
# === Shell & terminal ===       (stow, tmux, fzf, ripgrep, fd, bat, ...)
# === Languages & toolchains === (go, node, nvm, rustup, swift, deno, uv, lua, ruby, ...)
# === Cloud & infra ===          (awscli, aws-sam-cli, flyctl, terraform, k9s, kustomize, ...)
# === Data & services ===        (postgresql@16, redis, mongosh, mongodb-community, supabase)
# === Media & docs ===           (ffmpeg, imagemagick, pandoc, graphviz, yt-dlp, ...)
# === GUI apps (casks) ===
# === Fonts ===
# === Go binaries ===
# === Cargo binaries ===
```

Entries already classified by reading the current Brewfile. No package
choices change during reorganization — only their grouping/order.

### Going forward: stop using `make brew-dump`

Hand-curate the Brewfile from now on. `brew bundle dump` would
overwrite the section comments and re-introduce VS Code extensions on a
machine that has them. Add a comment at the top of the Brewfile noting
this. Leave the `brew-dump` Makefile target in place but unused — its
output can still be useful for one-off comparison, just not a wholesale
replacement.

## `scripts/bootstrap.sh`

Single bash script, ~80 lines. Runs on a fresh new MBP. Idempotent:
every step gates on its own pre-condition and prints `pass` / `skip` /
`fail`.

### Steps (in order)

1. **Sanity check** — abort unless macOS Apple Silicon.
2. **Xcode CLT** — `xcode-select -p` ⇒ skip; else `xcode-select
   --install` (which opens a GUI prompt). Script exits with a message
   asking the user to re-run after install completes. No way around the
   GUI; this is fine.
3. **Homebrew** — `command -v brew` ⇒ skip; else run the official
   `/bin/bash -c "$(curl -fsSL .../install.sh)"` one-liner.
4. **Clone dotfiles** — if `~/dotfiles` missing, `git clone
   git@github.com:qiushiyan/dotfiles.git ~/dotfiles`. Assumes SSH key
   is already restored (see "Restore secrets *before* bootstrap" note
   below).
5. **Stow** — `cd ~/dotfiles && make install`.
6. **Pre-toolchain** — to make step 7 (`make brew`) succeed end-to-end,
   `cargo` and `go` must be on PATH *before* `brew bundle` reaches the
   `cargo "..."` and `go "..."` entries. The Brewfile installs `rustup`
   and `go` as Homebrew formulae, but `rustup` is just `rustup-init` —
   it does not put `cargo` on PATH until initialized.
   - `brew install go rustup` (idempotent; harmless if already done by
     a later `make brew` call).
   - If `cargo` not on PATH: `rustup-init -y --default-toolchain
     stable` then `source "$HOME/.cargo/env"`.
7. **Brewfile** — `make brew`. Now the cargo and go entries succeed.
8. **Node toolchain** — source nvm, install latest LTS, set as default.
9. **Default shell** — `chsh -s "$(brew --prefix)/bin/zsh"` if not
   already.
10. **Print next-steps** pointing at `docs/MIGRATION.md`.

### Conventions

- `set -euo pipefail` at top.
- One bash function per step (`step_xcode_clt`, `step_homebrew`, etc.).
- `bootstrap.sh` with no arg runs all steps; `bootstrap.sh <step_name>`
  runs one step (so the user can re-run `step_brewfile` after fixing
  e.g. an upstream tap problem).
- `==> step name` headers; final summary line at the end.
- Never asks for sudo upfront. Homebrew installer asks for itself when
  needed. `chsh` may prompt for the login password; that's expected.

### Failure mode

Fail loud. `set -e` exits on first error. The final summary line tells
the user which step failed. They can re-run that step alone after
investigating.

### Notable non-goals

- Does not restore secrets.
- Does not install Logitech G Hub or other manual-install apps.
- Does not apply `defaults write` tweaks.
- Does not configure iCloud / Keychain / Apple ID — that's the macOS
  Setup Assistant's job ("Set up with iPhone" handles it).

### Bootstrap-vs-secrets ordering

Step 4 needs an SSH key to clone the repo over SSH. Two options
documented in `MIGRATION.md`:

- **Recommended:** restore `~/.ssh/` *before* running bootstrap. Order
  in playbook: setup OS → restore secrets → run bootstrap.
- **Alternative:** clone via HTTPS for the bootstrap, then switch the
  remote to SSH after secrets are restored. Viable but adds friction.

The script itself uses `git clone` with whatever URL the user
configures (defaults to SSH); recovery is by editing the script before
running, not by branching logic inside it.

## `scripts/list-secrets.sh`

Pure-read script. Runs on the **old** machine, before wipe. Produces:

1. Human-readable summary printed to stdout.
2. A `secrets-manifest.txt` (rsync `--files-from` format) written to
   the current directory.

### What it scans

| Path | Treatment |
|---|---|
| `~/.secrets` | Include if present |
| `~/.ssh/` (whole directory) | Include if present |
| `~/.gnupg/` | Include if present |
| `~/.aws/` | Include if present |
| `~/.netrc` | Include if present |
| `~/.npmrc` | Include if present |
| `~/.kube/config` | Include if present |
| `~/.docker/config.json` | Include if present |
| `~/.config/gh/` | **Skip** — recommend `gh auth login` |
| `~/.config/gcloud/` | **Skip** — recommend `gcloud auth login` |

For each path: print `[present]` / `[missing]`, total size, brief note.
For `[skip]` entries, print the recommended re-auth command.

### What it does *not* do

- Never reads or prints contents of any sensitive file.
- Does not move, copy, or modify anything. The user runs `rsync`
  themselves.

### Sample output (for reference)

```
== Sensitive paths to transfer ==
[present]  ~/.secrets                    627B
[present]  ~/.ssh/                       54K  (11 keypairs + config.local)
[present]  ~/.gnupg/                     32K
[present]  ~/.aws/                       2.1K
[present]  ~/.netrc                      202B
[present]  ~/.npmrc                      468B
[present]  ~/.kube/config                12K
[present]  ~/.docker/config.json         2.4K
[skip]     ~/.config/gh/                 (re-auth with `gh auth login`)
[skip]     ~/.config/gcloud/             (re-auth with `gcloud auth login`)

Wrote secrets-manifest.txt — use:
  rsync -av --files-from=secrets-manifest.txt ~ user@new-mbp:/Users/qiushi/
```

## `docs/MIGRATION.md`

Plain markdown playbook. Sections:

### Before you wipe the old Mac
- Push all local repo work (including in-progress branches).
- Run `scripts/list-secrets.sh`; review the output and `secrets-manifest.txt`.
- Choose transfer mechanism: rsync over LAN (recommended), USB, or AirDrop.
- Optional: kick off a Time Machine backup as a safety net.
- Don't sign out of iCloud on the old machine until the new one is set up.

### Setting up the new Mac (macOS-level)
1. Setup Assistant → "Set up with iPhone" (Apple ID, Wi-Fi, iCloud Keychain in one shot).
2. Sign in to iCloud — restores the macOS Passwords app entries automatically.
3. Enable FileVault (System Settings → Privacy & Security).
4. Optional: Time Machine to a new external drive.

### Restore secrets (before running bootstrap)
- Transfer the files listed in `secrets-manifest.txt`. Example rsync over LAN:
  ```
  rsync -av --files-from=secrets-manifest.txt ~ user@new-mbp:/Users/qiushi/
  ```
- After transfer, fix permissions: `chmod 600 ~/.ssh/id_*`.
- Verify quickly:
  - `ssh -T git@github.com`
  - `gpg --list-secret-keys`
  - `aws sts get-caller-identity`

### Run bootstrap
```
git clone git@github.com:qiushiyan/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```
Re-run individual steps if anything fails: `./scripts/bootstrap.sh brewfile`.

### Re-auth (rather than copying state)
- `gh auth login`
- `gcloud auth login && gcloud auth application-default login`

### Manual installs (NOT in Brewfile)
- **Logitech G Hub** — download from logitech.com/g-hub.
- (Add others here as encountered.)

### App login pass
Walk through Dock / Launchpad and log in: Slack, Linear, Raycast, etc.
iCloud Keychain should pre-fill most credentials.

### Verification checklist
- [ ] `make install` reports clean (no Stow conflicts).
- [ ] `make brew` reports nothing missing.
- [ ] New terminal opens cleanly (no zsh module errors).
- [ ] `git commit -S` succeeds (if using GPG signing).
- [ ] Neovim opens, plugins load.
- [ ] `tmux` starts.
- [ ] Ghostty shows expected fonts.

## Files-outside-repo summary (reference)

These are intentionally not in dotfiles and need manual transfer:

| Path | Sensitive | Transfer mechanism |
|---|---|---|
| `~/.secrets` | yes | rsync / scp |
| `~/.ssh/` (keys + `config.local`) | yes | rsync / scp |
| `~/.gnupg/` | yes | rsync / scp; verify `gpg --list-secret-keys` after |
| `~/.aws/credentials`, `~/.aws/config` | yes | rsync / scp |
| `~/.netrc` | yes | rsync / scp |
| `~/.npmrc` | yes | rsync / scp |
| `~/.kube/config` | medium | rsync / scp |
| `~/.docker/config.json` | medium | rsync / scp |
| `~/.config/gh/` | medium | re-auth via `gh auth login` |
| `~/.config/gcloud/` | medium | re-auth via `gcloud auth login` |
| iCloud Keychain | high | "Set up with iPhone" + iCloud sign-in |
| App logins (Slack/Linear/etc.) | medium | manual; Keychain pre-fills most |

Stale dotdirs to *avoid* dragging over (visible in `ls ~/.* `):
`.amazon-q.dotfiles.bak`, `.codewhisperer.dotfiles.bak`, `.cline`,
`.continue`, `.codeium`, `.codebuddy`, `.augment`, `.copilot`,
`.cookiecutters`, `.cookiecutter_replay`. These are byproducts of AI
tools no longer in use. Fresh setup naturally drops them.

## Decisions & rationale

- **Approach C (script + playbook)** chosen over script-only or
  playbook-only. Script earns its keep on Brew install / Stow /
  toolchain. Playbook earns its keep on secrets and judgment calls.
- **Lean over modular** — single `bootstrap.sh` rather than a directory
  of small scripts. Easier to read; the user migrates infrequently.
- **Hand-curated Brewfile, no `brew-dump`** — `dump` produces a
  Brewfile that re-introduces unwanted entries. Keeping it curated by
  hand is worth the small overhead.
- **Restore secrets before bootstrap** — simpler than HTTPS-then-SSH
  switcheroo for git. Documented in playbook.
- **`list-secrets.sh` is read-only** — never copies, never reads
  contents. The user owns the actual transfer.
- **No `defaults write` automation** — out of scope for this round;
  can add later as a follow-up.

## Open items / follow-ups (post-migration)

- macOS `defaults` tweaks: a follow-up `scripts/macos-defaults.sh` if
  the user finds themselves manually configuring the same System
  Settings panes both times.
- Once the new machine is set up, revisit Brewfile to remove anything
  that still feels unused — easier to spot when fresh.
