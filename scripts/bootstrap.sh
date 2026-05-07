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

step_thirdparty() {
    say "Third-party shell + tmux plugins (git-cloned, not in Brewfile)"
    local clones=(
        "https://github.com/zsh-users/zsh-syntax-highlighting.git|$HOME/zsh-syntax-highlighting"
        "https://github.com/zsh-users/zsh-autosuggestions|$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
        "https://github.com/tmux-plugins/tpm|$HOME/.config/tmux/plugins/tpm"
        "https://github.com/jimeh/tmuxifier|$HOME/.config/tmux/plugins/tmuxifier"
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
    # (tmux-sensible, tmux-resurrect, vim-tmux-navigator, catppuccin/tmux).
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
    if [[ -x "$HOME/Library/pnpm/pnpm" ]]; then
        ok "pnpm $("$HOME/Library/pnpm/pnpm" --version) already installed"
    else
        curl -fsSL https://get.pnpm.io/install.sh | sh -
        ok "pnpm installed at ~/Library/pnpm/"
    fi
}

step_macos_defaults() {
    say "macOS defaults"
    # Natural scrolling off (Windows/Linux-style: wheel down scrolls page down).
    # Single global pref controls BOTH mouse and trackpad; the GUI's two
    # toggles in System Settings are aliases for this same key.
    # Takes effect after logout/reboot.
    defaults write -g com.apple.swipescrolldirection -bool false
    ok "natural scrolling: off (logout/reboot to apply)"
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
    thirdparty
    node
    macos_defaults
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
