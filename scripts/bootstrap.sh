#!/usr/bin/env bash
# Bootstrap script for a fresh macOS machine.
# Idempotent: every step gates on its own pre-condition.
#
# Every machine (mac, mini, mini2) runs it; the machine's name decides the
# stow list, the Brewfile's sections and the power settings.
#
# Usage:
#   BOOTSTRAP_MACHINE=mini2 ./scripts/bootstrap.sh   # first run: name the machine
#   ./scripts/bootstrap.sh                # later runs read ~/.config/machine
#   ./scripts/bootstrap.sh <step> [step]  # run specific steps, e.g. brewfile

set -euo pipefail

# HTTPS through gh's credential helper, like every clone twin makes: a
# fresh machine has no GitHub SSH key.
REPO_URL="https://github.com/qiushiyan/dotfiles.git"
REPO_DIR="$HOME/dotfiles"
MARKER="$HOME/.config/machine"

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
    # The stow step runs before the Brewfile, so stow comes first.
    have stow || brew install stow
    ok "stow"
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

step_machine() {
    say "Machine marker ($MARKER)"
    local current="" want="${BOOTSTRAP_MACHINE:-}"
    [[ -r "$MARKER" ]] && current="$(tr -d '[:space:]' < "$MARKER")"
    if [[ -z "$want" ]]; then
        [[ -n "$current" ]] || { echo "No $MARKER: run with BOOTSTRAP_MACHINE=<mac|mini|mini2>."; exit 1; }
        want="$current"
    fi
    # hosts/<machine>.zsh is what makes a name a machine of this repository.
    if [[ ! -r "$REPO_DIR/zsh/.config/zsh/hosts/$want.zsh" ]]; then
        echo "Unknown machine '$want': add zsh/.config/zsh/hosts/$want.zsh first."
        exit 1
    fi
    if [[ -n "$current" && "$current" != "$want" ]]; then
        echo "$MARKER says '$current', not '$want'. Fix it by hand if this machine changed names."
        exit 1
    fi
    mkdir -p "$(dirname "$MARKER")"
    printf '%s\n' "$want" > "$MARKER"
    MACHINE="$want"
    ok "$MACHINE"
}

machine() {
    [[ -n "${MACHINE:-}" ]] || MACHINE="$(tr -d '[:space:]' < "$MARKER" 2>/dev/null || true)"
    [[ -n "$MACHINE" ]] || { echo "No machine marker: run the machine step first."; exit 1; }
    printf '%s' "$MACHINE"
}

# The packages twin's manifest lists for this machine, one line; empty when it
# lists none, which means the Makefile's default set (as `twin dotfiles apply`).
manifest_packages() {
    awk -v sect="[machines.$(machine)]" '
        $0 == sect { inside = 1; next }
        /^\[/ { inside = 0 }
        inside && /^packages *=/ { collect = 1 }
        collect {
            line = $0; sub(/#.*/, "", line)
            while (match(line, /"[^"]+"/)) {
                printf "%s ", substr(line, RSTART + 1, RLENGTH - 2)
                line = substr(line, RSTART + RLENGTH)
            }
            if ($0 ~ /\]/) collect = 0
        }
    ' "$REPO_DIR/twin/.config/twin/twin.toml"
}

step_stow() {
    say "Stow packages"
    cd "$REPO_DIR"
    local pk
    pk="$(manifest_packages)"
    if [[ -n "$pk" ]]; then
        make install PACKAGES="$pk"
        ok "stowed the manifest's list for $(machine): $pk"
    else
        make install
        ok "stowed the default set: $(make -s list)"
    fi
}

step_pre_toolchain() {
    say "Pre-toolchain (go + rust, before make brew)"
    brew install go
    # rustup's own installer, not Homebrew's keg-only rustup (which no longer
    # ships rustup-init): ~/.cargo/bin and ~/.cargo/env, which .zshenv sources.
    if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
        ok "cargo already installed"
    else
        curl -fsSL https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path
        ok "rustup initialized"
    fi
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
}

step_local_tap() {
    say "Local tap qiushiyan/local (tmux-popupfix, docs/tmux-popup-patch.md)"
    local formula
    if brew tap | grep -qx qiushiyan/local; then
        ok "already tapped"
    else
        brew tap-new --no-git qiushiyan/local >/dev/null
        ok "created"
    fi
    formula="$(brew --repo qiushiyan/local)/Formula/tmux-popupfix.rb"
    mkdir -p "$(dirname "$formula")"
    cp "$REPO_DIR/docs/tmux-popupfix.rb" "$formula"
    ok "formula copied from docs/tmux-popupfix.rb"
}

step_trust() {
    say "Trust the Brewfile's third-party formulae"
    # Homebrew loads a formula from a tap outside its own only once trusted
    # (~/.homebrew/trust.json); the Brewfile names exactly these.
    local f
    for f in $(cd "$REPO_DIR" && brew bundle list --file=Brewfile --formula | grep /); do
        brew trust --formula "$f" >/dev/null
        ok "$f"
    done
}

step_brewfile() {
    say "Brewfile ($(machine))"
    cd "$REPO_DIR"
    # --adopt: an app installed by hand before the Brewfile ran (Slack, the
    # Tailscale app) becomes the cask's instead of failing the install.
    HOMEBREW_CASK_OPTS="${HOMEBREW_CASK_OPTS:-} --adopt" make brew
}

step_thirdparty() {
    say "Third-party shell + tmux plugins (git-cloned, not in Brewfile)"
    local clones=(
        "https://github.com/zsh-users/zsh-syntax-highlighting.git|$HOME/zsh-syntax-highlighting"
        "https://github.com/zsh-users/zsh-autosuggestions|$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
        "https://github.com/tmux-plugins/tpm|$HOME/.config/tmux/plugins/tpm"
        "https://github.com/yetone/smart-suggestion|$HOME/.config/smart-suggestion"
    )

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
        ok "oh-my-zsh installed"
    else
        ok "oh-my-zsh already installed"
    fi

    for entry in "${clones[@]}"; do
        local url="${entry%%|*}"
        local dest="${entry##*|}"
        if [[ -d "$dest/.git" ]]; then
            ok "$(basename "$dest") already cloned"
        else
            mkdir -p "$(dirname "$dest")"
            git clone --depth 1 "$url" "$dest"
            ok "cloned $(basename "$dest")"
        fi
    done

    # smart-suggestion ships Go source, not a binary — build it once.
    local ss_dir="$HOME/.config/smart-suggestion"
    if [[ -d "$ss_dir" && ! -x "$ss_dir/smart-suggestion" ]]; then
        (cd "$ss_dir" && bash build.sh)
        ok "smart-suggestion binary built"
    fi

    # Trigger tpm to fetch the rest of the tmux plugins declared in tmux.conf
    # (tmux-resurrect, tmux-continuum, vim-tmux-navigator, catppuccin/tmux,
    # tmux-fzf-url).
    # tpm only auto-installs from inside tmux on `prefix + I`; running its
    # install_plugins script here makes the bootstrap fully non-interactive.
    if [[ -x "$HOME/.config/tmux/plugins/tpm/bin/install_plugins" ]]; then
        "$HOME/.config/tmux/plugins/tpm/bin/install_plugins" >/dev/null
        ok "tpm plugins installed"
    fi
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

    # pnpm via the standalone installer — keeps the binary at
    # ~/Library/pnpm/ (the path .zshrc's PNPM_HOME already expects)
    # so it survives nvm version switches. Don't use `npm install -g`:
    # the block-npm.sh hook in claude/ rejects it on principle.
    # Pinned to major 11, as on every machine; not the Rust-port 12.
    if [[ -x "$HOME/Library/pnpm/pnpm" ]]; then
        ok "pnpm $("$HOME/Library/pnpm/pnpm" --version) already installed"
    else
        curl -fsSL https://get.pnpm.io/install.sh | PNPM_VERSION=11 sh -
        ok "pnpm installed at ~/Library/pnpm/"
    fi
}

step_python() {
    say "Python (uv)"
    uv python install 3.14
    ok "python3.14"
}

step_agents() {
    say "Claude Code and Codex CLIs (native installers, ~/.local/bin)"
    if [[ -x "$HOME/.local/bin/claude" ]]; then
        ok "claude already installed (auto-updates)"
    else
        curl -fsSL https://claude.ai/install.sh | bash
        ok "claude installed"
    fi
    # A desk machine has the Brewfile's codex cask; the native installer
    # would put a second codex ahead of it on PATH.
    if have codex; then
        ok "codex already installed: $(command -v codex)"
    else
        curl -fsSL https://chatgpt.com/codex/install.sh | sh
        ok "codex installed"
    fi
}

step_twin() {
    say "twin (~/dev/twin): clones, carried files and tools after this"
    local dir="$HOME/dev/twin"
    if [[ -d "$dir/.git" ]]; then
        ok "already cloned at $dir"
    else
        mkdir -p "$HOME/dev"
        git clone https://github.com/qiushiyan/twin.git "$dir"
    fi
    make -C "$dir" install
    ok "twin installed; next: twin repos clone --all, twin tools install --all (docs/twin.md)"
}

step_macos_defaults() {
    say "macOS defaults"
    # Natural scrolling off (Windows/Linux-style: wheel down scrolls page down).
    # Single global pref controls BOTH mouse and trackpad; the GUI's two
    # toggles in System Settings are aliases for this same key.
    # Takes effect after logout/reboot.
    defaults write -g com.apple.swipescrolldirection -bool false
    ok "natural scrolling: off (logout/reboot to apply)"

    # Power management. Stock macOS / a config profile can leave system
    # sleep absurdly low (seen: sleep=1 min, so the Mac naps after a
    # minute idle). pmset values are in MINUTES, 0 = never. Needs sudo
    # (unlike `defaults write`) — you'll be prompted for your password here.
    if [[ "$(machine)" == mac ]]; then
        # -b battery, -c charger/AC
        sudo pmset -b sleep 30 displaysleep 10   # battery: sleep 30m, screen off 10m
        sudo pmset -c sleep 0  displaysleep 20   # AC:      never sleep, screen off 20m
        ok "power: battery sleep 30m / AC never (verify with 'pmset -g custom')"
    else
        # A mini is reached over the tailnet: never sleep, come back after a
        # power loss, wake on LAN.
        sudo pmset -a sleep 0 displaysleep 20 autorestart 1 womp 1
        ok "power: never sleep, restart after power loss, wake on LAN"
    fi
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

step_finish() {
    say "All automated steps done"
    echo "    Next: read $REPO_DIR/docs/MIGRATION.md for the manual checklist"
    echo "    (secrets restoration, app re-logins, manual installs, verification)."
}

ALL_STEPS=(
    check_macos
    xcode_clt
    homebrew
    clone
    machine
    stow
    pre_toolchain
    local_tap
    trust
    brewfile
    thirdparty
    node
    python
    agents
    twin
    macos_defaults
    default_shell
    finish
)

# The clone's state as git sees it, one line per changed or untracked path.
tree_state() {
    [[ -d "$REPO_DIR/.git" ]] && git -C "$REPO_DIR" status --porcelain 2>/dev/null
    return 0
}

# Names what changed in the clone since $1 (tree_state before the run). Stowed
# links make the clone the target of anything an installer writes into a
# linked file or folded directory: pnpm's PATH block into .zshrc, uv's Pythons
# into a folded ~/.local/share.
report_tree() {
    local new line
    new=$(comm -13 <(printf '%s\n' "$1" | sort) <(tree_state | sort) | sed '/^$/d')
    [[ -n $new ]] || return 0
    say "Changed in $REPO_DIR during this run: an installer wrote through a link"
    while IFS= read -r line; do echo "    $line"; done <<<"$new"
    echo "    Review with: git -C $REPO_DIR status; revert what the repository should not hold."
}

main() {
    local before
    before=$(tree_state)
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
    report_tree "$before"
}

# Sourced (tests), it defines the steps and runs nothing.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
