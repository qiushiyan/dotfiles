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
    stow
    pre_toolchain
    brewfile
    node
    default_shell
    finish
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
