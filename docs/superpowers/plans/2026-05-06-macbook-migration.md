# MacBook Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the dotfiles repo and surrounding workflow for migration to a new MBP (M5): clean up the Brewfile, add a bootstrap script for the new machine, add a secrets-listing helper for the old machine, and document the manual playbook in `docs/MIGRATION.md`.

**Architecture:** Shell scripts only (bash). No new dependencies. Brewfile is hand-curated going forward. New files live in `scripts/` and `docs/`. No changes to Stow packages.

**Tech Stack:** bash, Homebrew, GNU Stow, shellcheck for linting.

**Spec:** `docs/superpowers/specs/2026-05-06-macbook-migration-design.md`.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `Brewfile` | MODIFIED | Hand-curated package list. Drops `fig`, `hyper`, `logitech-g-hub`, `tonisives/tap/ovim`, `pgadmin4`, `rstudio`, `rim`, `learlab/itell`, `heroku` tap, all 156 `vscode "..."` entries. Adds section-comment groups + a header warning against `brew bundle dump`. |
| `scripts/bootstrap.sh` | NEW | Idempotent first-run script for the new MBP. Installs Xcode CLT, Homebrew, clones dotfiles, runs `make install`, initializes rustup before `make brew`, sets up Node via nvm, sets default shell. Each step is a function; can be invoked individually. |
| `scripts/list-secrets.sh` | NEW | Read-only audit script for the **old** machine. Lists which sensitive paths exist (`~/.secrets`, `~/.ssh/`, `~/.gnupg/`, etc.) and writes a `secrets-manifest.txt` rsync file list. Never reads contents. |
| `docs/MIGRATION.md` | NEW | Playbook covering the manual steps: pre-wipe checklist, secrets transfer, bootstrap, re-auth flows, manual app installs (Logitech G Hub), and a verification checklist. |

Existing files left untouched: every Stow package, `Makefile`, `CLAUDE.md`, `AGENTS.md`.

---

## Task 1: Brewfile cleanup

**Files:**
- Modify: `Brewfile` (full rewrite of contents — easiest to express)

**Context:** The current Brewfile is 337 lines: 11 taps, 110 brews, 34 casks, 156 VS Code extensions, 21 go binaries, 5 cargo binaries. Target: 7 taps, 109 brews, 27 casks (12 apps + 15 fonts), 0 vscode, 21 go, 5 cargo.

- [ ] **Step 1: Rewrite `Brewfile` with the curated content below**

Use the Write tool to overwrite `Brewfile` with this exact content:

```ruby
# Brewfile — manually curated. Do NOT replace via `brew bundle dump`;
# that would re-introduce VS Code extensions and erase these section
# comments. Edit by hand instead.

# === Taps ===
tap "hashicorp/tap"
tap "homebrew/cask"
tap "homebrew/core"
tap "jandedobbeleer/oh-my-posh"
tap "mongodb/brew"
tap "qiushiyan/degit", "https://github.com/qiushiyan/degit"
tap "supabase/tap"

# === Build dependencies & libraries ===
brew "libpng"
brew "xz"
brew "zstd"
brew "openssl@3"
brew "protobuf"
brew "grpc"
brew "thrift"
brew "apache-arrow"
brew "apr-util"
brew "automake"
brew "cryptography"
brew "libgit2"
brew "glib"
brew "gmp"
brew "gcc"
brew "libomp", link: true
brew "clp"
brew "cmake"
brew "libavif"
brew "gd"
brew "pkgconf"
brew "hdf5"
brew "krb5"
brew "shared-mime-info"
brew "libheif"
brew "libspatialite"
brew "netcdf"
brew "openjpeg"
brew "gdal"
brew "gdk-pixbuf"
brew "gobject-introspection"
brew "netpbm"
brew "harfbuzz"
brew "pango"
brew "librsvg"
brew "ldns"
brew "libdap"
brew "libfido2"
brew "libsodium"
brew "tcl-tk"
brew "open-mpi"

# === Shell & terminal ===
brew "bat"
brew "bc"
brew "coreutils"
brew "dust"
brew "fd"
brew "fzf"
brew "jq"
brew "lazygit"
brew "macos-trash", link: true
brew "moreutils", link: false
brew "neovim"
brew "openssh"
brew "ripgrep"
brew "rsync"
brew "sesh"
brew "stow"
brew "tldr"
brew "tmux"
brew "trash"
brew "tree"
brew "wget"
brew "z"
brew "lua"
brew "luarocks"

# === Languages & toolchains ===
brew "go"
brew "node"
brew "nvm"
brew "rustup"
brew "swift"
brew "deno"
brew "uv"
brew "ruby", link: true
brew "python-setuptools"

# === Code formatters & linters ===
brew "ast-grep"
brew "biome"
brew "ruff"
brew "stylua"
brew "xcode-build-server"

# === Cloud, infra, dev services ===
brew "act"
brew "aws-sam-cli"
brew "awscli"
brew "docker"
brew "flyctl"
brew "gh"
brew "git-lfs"
brew "goreleaser"
brew "k9s"
brew "kustomize"
brew "rclone"
brew "redis"
brew "postgresql@16", restart_service: :changed
brew "mongosh"
brew "protoc-gen-go"
brew "protoc-gen-go-grpc"
brew "hashicorp/tap/terraform"
brew "mongodb/brew/mongodb-community"
brew "supabase/tap/supabase"
brew "qiushiyan/degit/degit"

# === Media, docs, AI tooling ===
brew "ffmpeg"
brew "graphviz"
brew "httpie"
brew "imagemagick"
brew "pandoc"
brew "yt-dlp"
brew "gnupg"
brew "opencode"
brew "qwen-code"
brew "jandedobbeleer/oh-my-posh/oh-my-posh"

# === GUI apps (casks) ===
cask "codex"
cask "discord"
cask "ghostty"
cask "linear-linear"
cask "mongodb-compass"
cask "postman"
cask "raycast"
cask "rectangle"
cask "sf-symbols"
cask "slack"
cask "swiftformat-for-xcode"
cask "xquartz"

# === Fonts ===
cask "font-blex-mono-nerd-font"
cask "font-cascadia-code"
cask "font-code-new-roman-nerd-font"
cask "font-hack-nerd-font"
cask "font-iosevka"
cask "font-iosevka-term-nerd-font"
cask "font-maple-mono-nf-cn"
cask "font-noto-color-emoji"
cask "font-noto-emoji"
cask "font-noto-nerd-font"
cask "font-noto-sans-cjk-sc"
cask "font-noto-serif-cjk-sc"
cask "font-sf-mono"
cask "font-sf-pro"
cask "font-victor-mono-nerd-font"

# === Go binaries (installed via `go install`) ===
go "github.com/cosmtrek/air"
go "github.com/hibiken/asynqmon/cmd/asynqmon"
go "github.com/qiushiyan/caturday"
go "github.com/spf13/cobra-cli"
go "github.com/go-delve/delve/cmd/dlv"
go "github.com/divan/expvarmon"
go "github.com/segmentio/golines"
go "golang.org/x/tools/gopls"
go "github.com/rakyll/hey"
go "sigs.k8s.io/kind"
go "github.com/tj/mmake/cmd/mmake"
go "go.uber.org/mock/mockgen"
go "go.uber.org/nilaway/cmd/nilaway"
go "golang.org/x/pkgsite/cmd/pkgsite"
go "google.golang.org/protobuf/cmd/protoc-gen-go"
go "github.com/qiushiyan/qlang/cmd/q"
go "github.com/qiushiyan/gemini-search"
go "honnef.co/go/tools/cmd/staticcheck"
go "github.com/swaggo/swag/cmd/swag"
go "github.com/go-swagger/go-swagger/cmd/swagger"
go "github.com/wailsapp/wails/v2/cmd/wails"

# === Cargo binaries (installed via `cargo install`) ===
cargo "cargo-wasi"
cargo "evcxr_jupyter"
cargo "evcxr_repl"
cargo "trunk"
cargo "wasm-bindgen-cli"
```

- [ ] **Step 2: Verify entry counts**

Run:
```bash
cd ~/dotfiles
echo "taps: $(grep -c '^tap ' Brewfile)"
echo "brews: $(grep -c '^brew ' Brewfile)"
echo "casks: $(grep -c '^cask ' Brewfile)"
echo "vscode: $(grep -c '^vscode ' Brewfile)"
echo "go: $(grep -c '^go ' Brewfile)"
echo "cargo: $(grep -c '^cargo ' Brewfile)"
```

Expected output exactly:
```
taps: 7
brews: 109
casks: 27
vscode: 0
go: 21
cargo: 5
```

If any count is off, re-check the Brewfile content against the source above. Do NOT proceed until counts match.

- [ ] **Step 3: Verify all listed brews/casks are still installable**

Run:
```bash
cd ~/dotfiles
brew bundle check --file=Brewfile --no-upgrade --verbose
```

Expected: exit code 0 with `The Brewfile's dependencies are satisfied.` (everything in the new, smaller Brewfile is already installed locally because we only removed entries — never added). If any item reports missing, that's a real bug — investigate before proceeding.

- [ ] **Step 4: Commit**

Run:
```bash
cd ~/dotfiles
git add Brewfile
git commit -m "$(cat <<'EOF'
Curate Brewfile: drop unused casks, all VS Code extensions, group with sections

Removes fig (discontinued), hyper (replaced by Ghostty), logitech-g-hub
(will be installed manually on new machine), tonisives/ovim, pgadmin4,
rstudio + R toolchain, learlab/itell, heroku tap, and all 156 vscode
entries (going Zed-only on new machine). Adds section-comment groups
and a header warning against `brew bundle dump`.
EOF
)"
```

---

## Task 2: Uninstall removed casks/taps from this machine

The user explicitly asked to clean up this machine in addition to the
Brewfile. This task purges the casks/taps we just dropped. **Note:**
`--zap` removes app config dirs too — destructive but intentional for
apps the user no longer uses.

**Files:** none modified — only Homebrew state on this machine.

- [ ] **Step 1: Uninstall casks we dropped (except logitech-g-hub, which user keeps on this machine)**

Run:
```bash
brew uninstall --cask --zap fig hyper pgadmin4 rstudio || true
brew uninstall --cask --zap tonisives/tap/ovim || true
brew uninstall --cask --zap gaborcsardi/rim/rim || true
```

Expected: each command either uninstalls the cask or reports it isn't installed (we use `|| true` so a missing cask doesn't abort). `--zap` also cleans up app config dirs.

- [ ] **Step 2: Uninstall the dropped formula and untap unused taps**

Run:
```bash
brew uninstall learlab/itell-cli/itell || true
brew untap heroku/brew tonisives/tap learlab/itell-cli gaborcsardi/rim || true
```

Expected: each succeeds or reports already absent.

- [ ] **Step 3: Sanity check — `brew bundle check` still clean**

Run:
```bash
cd ~/dotfiles
brew bundle check --file=Brewfile --no-upgrade
```

Expected: `The Brewfile's dependencies are satisfied.` Same as Task 1 Step 3 — the Brewfile didn't change, so this should still pass.

- [ ] **Step 4: No commit needed**

Nothing in the repo changed in this task. Continue to Task 3.

---

## Task 3: Create `scripts/bootstrap.sh`

**Files:**
- Create: `scripts/bootstrap.sh`

- [ ] **Step 1: Create the `scripts/` directory**

Run:
```bash
mkdir -p ~/dotfiles/scripts
```

Expected: directory exists. Idempotent.

- [ ] **Step 2: Write the script**

Use the Write tool to create `scripts/bootstrap.sh` with this exact content:

```bash
#!/usr/bin/env bash
# Bootstrap script for a fresh macOS machine.
# Idempotent: every step gates on its own pre-condition.
#
# Usage:
#   ./scripts/bootstrap.sh                # run all steps in order
#   ./scripts/bootstrap.sh <step> [step]  # run specific steps, e.g. brewfile

set -euo pipefail

REPO_URL="git@github.com:qiushiyan/dotfiles.git"
REPO_DIR="$HOME/dotfiles"

say()  { printf "==> %s\n" "$*"; }
ok()   { printf "    ok: %s\n" "$*"; }
skip() { printf "    skip: %s\n" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

step_check_macos() {
    say "Sanity check (macOS Apple Silicon)"
    [[ "$(uname)" == "Darwin" ]] || { echo "Not macOS — aborting."; exit 1; }
    [[ "$(uname -m)" == "arm64" ]] || { echo "Not Apple Silicon — aborting."; exit 1; }
    ok "macOS arm64"
}

step_xcode_clt() {
    say "Xcode Command Line Tools"
    if xcode-select -p >/dev/null 2>&1; then
        ok "already installed"
    else
        xcode-select --install || true
        echo "    A GUI prompt should appear. Re-run this script after install completes."
        exit 1
    fi
}

step_homebrew() {
    say "Homebrew"
    if have brew; then
        ok "already installed"
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
}

step_clone() {
    say "Clone dotfiles"
    if [[ -d "$REPO_DIR/.git" ]]; then
        ok "already cloned at $REPO_DIR"
    else
        git clone "$REPO_URL" "$REPO_DIR"
        ok "cloned to $REPO_DIR"
    fi
}

step_stow() {
    say "Stow packages"
    cd "$REPO_DIR"
    make install
    ok "stowed"
}

step_pre_toolchain() {
    say "Pre-toolchain (go + rustup, before make brew)"
    brew install go rustup
    if have cargo; then
        ok "cargo already on PATH"
    else
        rustup-init -y --default-toolchain stable --no-modify-path
        if [[ -r "$HOME/.cargo/env" ]]; then
            # shellcheck source=/dev/null
            source "$HOME/.cargo/env"
        fi
        ok "rustup initialized"
    fi
}

step_brewfile() {
    say "Brewfile"
    cd "$REPO_DIR"
    make brew
}

step_node() {
    say "Node toolchain (nvm + LTS)"
    export NVM_DIR="$HOME/.nvm"
    mkdir -p "$NVM_DIR"
    local nvm_sh
    nvm_sh="$(brew --prefix)/opt/nvm/nvm.sh"
    if [[ ! -r "$nvm_sh" ]]; then
        skip "nvm not found at $nvm_sh — was nvm installed by step_brewfile?"
        return
    fi
    # shellcheck source=/dev/null
    source "$nvm_sh"
    nvm install --lts
    nvm alias default 'lts/*'
    ok "node $(node --version)"
}

step_default_shell() {
    say "Default login shell"
    if [[ "${SHELL:-}" == */zsh ]]; then
        ok "already zsh ($SHELL)"
        return
    fi
    chsh -s /bin/zsh
    ok "set to /bin/zsh (open a new terminal to confirm)"
}

step_done() {
    say "All automated steps done"
    echo "    Next: read $REPO_DIR/docs/MIGRATION.md for the manual checklist"
    echo "    (secrets restoration, app re-logins, manual installs, verification)."
}

ALL_STEPS=(
    check_macos
    xcode_clt
    homebrew
    clone
    stow
    pre_toolchain
    brewfile
    node
    default_shell
    done
)

main() {
    if (( $# == 0 )); then
        for step in "${ALL_STEPS[@]}"; do
            "step_$step"
        done
    else
        for step in "$@"; do
            if ! declare -f "step_$step" >/dev/null; then
                echo "Unknown step: $step" >&2
                echo "Known steps: ${ALL_STEPS[*]}" >&2
                exit 2
            fi
            "step_$step"
        done
    fi
}

main "$@"
```

- [ ] **Step 3: Make it executable**

Run:
```bash
chmod +x ~/dotfiles/scripts/bootstrap.sh
```

Expected: no output. Verify:
```bash
ls -l ~/dotfiles/scripts/bootstrap.sh
```
Expected: permissions include `x` (e.g. `-rwxr-xr-x`).

- [ ] **Step 4: Lint with shellcheck**

Run:
```bash
shellcheck ~/dotfiles/scripts/bootstrap.sh
```

Expected: no output, exit 0. If shellcheck reports issues, fix them before continuing. (`shellcheck` is not in the Brewfile; if missing, `brew install shellcheck` first.)

- [ ] **Step 5: Smoke-test safe steps on this current machine**

Run:
```bash
~/dotfiles/scripts/bootstrap.sh check_macos
~/dotfiles/scripts/bootstrap.sh homebrew
~/dotfiles/scripts/bootstrap.sh clone
```

Expected output (on this current machine, with brew + clone already done):
```
==> Sanity check (macOS Apple Silicon)
    ok: macOS arm64
==> Homebrew
    ok: already installed
==> Clone dotfiles
    ok: already cloned at /Users/qiushi/dotfiles
```

Each command should exit 0. Do **not** run `xcode_clt` (would re-trigger GUI dialog), `pre_toolchain`/`brewfile` (would mutate brew state), `default_shell` (would prompt for sudo), or `done` (no side effects but uninteresting).

- [ ] **Step 6: Commit**

Run:
```bash
cd ~/dotfiles
git add scripts/bootstrap.sh
git commit -m "$(cat <<'EOF'
Add scripts/bootstrap.sh for new-machine setup

Idempotent first-run script: macOS sanity check, Xcode CLT, Homebrew,
clone repo, make install, install go+rustup before make brew (so cargo
entries succeed), make brew, nvm + LTS Node, default shell. Each step
is a function; can be invoked individually for re-runs.
EOF
)"
```

---

## Task 4: Create `scripts/list-secrets.sh`

**Files:**
- Create: `scripts/list-secrets.sh`

**Context:** Read-only audit script. Run on the **old** machine before wipe. Lists which sensitive paths exist locally + their sizes, and writes an rsync `--files-from`-compatible manifest. Never reads file contents.

- [ ] **Step 1: Write the script**

Use the Write tool to create `scripts/list-secrets.sh`:

```bash
#!/usr/bin/env bash
# Audit which sensitive paths exist on the OLD machine before migration.
# Read-only: prints sizes + names; never reads file contents.
# Writes secrets-manifest.txt (rsync --files-from format) to the cwd.
#
# Usage:
#   ./scripts/list-secrets.sh

set -euo pipefail

MANIFEST="secrets-manifest.txt"
: > "$MANIFEST"  # truncate

# Paths to copy verbatim. Manifest entries are paths relative to $HOME.
COPY_PATHS=(
    ".secrets"
    ".ssh"
    ".gnupg"
    ".aws"
    ".netrc"
    ".npmrc"
    ".kube/config"
    ".docker/config.json"
)

# Paths intentionally skipped (re-auth on new machine instead).
SKIP_PATHS=(
    ".config/gh:re-auth with \`gh auth login\`"
    ".config/gcloud:re-auth with \`gcloud auth login\`"
)

human_size() {
    local path="$1"
    if [[ -e "$HOME/$path" ]]; then
        du -sh "$HOME/$path" 2>/dev/null | awk '{print $1}'
    else
        echo "-"
    fi
}

printf "== Sensitive paths to transfer ==\n\n"

for path in "${COPY_PATHS[@]}"; do
    if [[ -e "$HOME/$path" ]]; then
        size="$(human_size "$path")"
        printf "[present]  ~/%-30s %6s\n" "$path" "$size"
        printf "%s\n" "$path" >> "$MANIFEST"
    else
        printf "[missing]  ~/%-30s (skipping)\n" "$path"
    fi
done

printf "\n== Re-auth (skip copy; re-authenticate on new machine) ==\n\n"

for entry in "${SKIP_PATHS[@]}"; do
    path="${entry%%:*}"
    note="${entry#*:}"
    if [[ -e "$HOME/$path" ]]; then
        printf "[skip]     ~/%-30s %s\n" "$path" "$note"
    else
        printf "[absent]   ~/%-30s (no current session)\n" "$path"
    fi
done

printf "\nWrote %s with %d entries.\n" "$MANIFEST" "$(wc -l < "$MANIFEST" | tr -d ' ')"
printf "\nTransfer (LAN, requires SSH access from old to new):\n"
printf "  rsync -av --files-from=%s ~ user@new-mbp:/Users/qiushi/\n" "$MANIFEST"
printf "\nOr via USB/AirDrop: tar the listed paths from \$HOME and copy.\n"
```

- [ ] **Step 2: Make it executable**

Run:
```bash
chmod +x ~/dotfiles/scripts/list-secrets.sh
```

- [ ] **Step 3: Lint with shellcheck**

Run:
```bash
shellcheck ~/dotfiles/scripts/list-secrets.sh
```

Expected: no output, exit 0.

- [ ] **Step 4: Run it on this machine and inspect output**

Run:
```bash
cd /tmp && rm -f secrets-manifest.txt && ~/dotfiles/scripts/list-secrets.sh
```

Expected: prints a "== Sensitive paths to transfer ==" table where the user's known sensitive paths show `[present]`. At minimum these should be present (based on repo audit done during brainstorming):

- `~/.secrets`
- `~/.ssh`
- `~/.gnupg`
- `~/.aws`
- `~/.netrc`
- `~/.npmrc`
- `~/.kube/config`
- `~/.docker/config.json`

The "Re-auth" section should show both `~/.config/gh` and `~/.config/gcloud` as `[skip]` (both exist on this machine).

Verify the manifest:
```bash
cat /tmp/secrets-manifest.txt
```
Expected: 8 lines, each a path relative to `$HOME` (no leading `~/`, no leading `/`).

- [ ] **Step 5: Clean up the test manifest**

Run:
```bash
rm -f /tmp/secrets-manifest.txt
```

- [ ] **Step 6: Commit**

Run:
```bash
cd ~/dotfiles
git add scripts/list-secrets.sh
git commit -m "$(cat <<'EOF'
Add scripts/list-secrets.sh to audit sensitive paths before migration

Read-only audit: prints which sensitive paths exist (~/.secrets, ~/.ssh,
~/.gnupg, ~/.aws, ~/.netrc, ~/.npmrc, ~/.kube/config,
~/.docker/config.json) with sizes, and writes an rsync-compatible
secrets-manifest.txt. Skips ~/.config/gh and ~/.config/gcloud (re-auth
on new machine instead). Never reads file contents.
EOF
)"
```

---

## Task 5: Create `docs/MIGRATION.md`

**Files:**
- Create: `docs/MIGRATION.md`

- [ ] **Step 1: Write the playbook**

Use the Write tool to create `docs/MIGRATION.md`:

```markdown
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

## Re-auth (rather than copying state)

```
gh auth login
gcloud auth login && gcloud auth application-default login
```

## Manual installs (NOT in Brewfile)

Apps you've chosen to install outside Homebrew. Add to this list as you
encounter others.

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
```

- [ ] **Step 2: Visually skim the rendered markdown**

Run:
```bash
glow ~/dotfiles/docs/MIGRATION.md 2>/dev/null || cat ~/dotfiles/docs/MIGRATION.md
```

Expected: tables render, code fences are correct, no broken sections. (`glow` is optional; falls through to `cat`.)

- [ ] **Step 3: Commit**

Run:
```bash
cd ~/dotfiles
git add docs/MIGRATION.md
git commit -m "$(cat <<'EOF'
Add docs/MIGRATION.md playbook for new-machine migration

Covers the manual steps that bootstrap.sh and list-secrets.sh don't
handle: pre-wipe checklist, secrets transfer, post-bootstrap re-auth
flows (gh, gcloud), manual installs (Logitech G Hub), app login pass,
and a verification checklist.
EOF
)"
```

---

## Task 6: Final integration check

This task verifies that the cleanup didn't break the live system.

- [ ] **Step 1: `make install` still clean**

Run:
```bash
cd ~/dotfiles
make install
```

Expected: no Stow conflicts. (We didn't touch any Stow package, but verifying as a regression check.)

- [ ] **Step 2: Brewfile still satisfies**

Run:
```bash
cd ~/dotfiles
brew bundle check --file=Brewfile --no-upgrade
```

Expected: `The Brewfile's dependencies are satisfied.`

- [ ] **Step 3: Both new scripts pass shellcheck**

Run:
```bash
shellcheck ~/dotfiles/scripts/bootstrap.sh ~/dotfiles/scripts/list-secrets.sh
```

Expected: no output, exit 0.

- [ ] **Step 4: Verify scripts are executable and tracked by git**

Run:
```bash
cd ~/dotfiles
git ls-files scripts/ docs/MIGRATION.md
ls -l scripts/bootstrap.sh scripts/list-secrets.sh
```

Expected:
- `git ls-files` lists `scripts/bootstrap.sh`, `scripts/list-secrets.sh`, `docs/MIGRATION.md`.
- Both shell scripts have execute permissions (`-rwxr-xr-x` or similar).

- [ ] **Step 5: Confirm git history**

Run:
```bash
cd ~/dotfiles
git log --oneline -10
```

Expected: top 4 commits should be the four added in Tasks 1, 3, 4, 5
(in implementation order). If Task 2 was performed, no commit was added
(it only mutates Homebrew state).
