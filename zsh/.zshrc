# --------------------------------------------------------------------
# 1. SHELL BEHAVIOR & HISTORY
# --------------------------------------------------------------------
set -o vi
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_ALL_DUPS    # deduplicate older entries
setopt HIST_REDUCE_BLANKS      # strip extra whitespace
setopt SHARE_HISTORY           # share history across terminals
setopt INC_APPEND_HISTORY      # write immediately, not on exit

# 'v' in vi-mode opens current command in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# Restore common Ctrl bindings in vi-insert mode (not bound by default)
bindkey -M viins '^L' clear-screen
bindkey -M vicmd '^L' clear-screen

# ── Ctrl+D guard ────────────────────────────────────────────────────────────
# An accidental Ctrl+D must never silently close the last pane of a tmux window
# (losing e.g. a Claude Code session): prefix-x confirms before killing a
# window, and a bare Ctrl+D would not. Two layers, robust against keymap and
# plugin load order:
#
#   Floor — `setopt ignore_eof`: an option, not a binding, so no keymap switch
#     or plugin can clobber it. An empty-line EOF cannot exit zsh on its own;
#     if the widget is bypassed, the worst case is zsh's "use 'exit' to exit".
#   UX — a widget on ^D that, on an empty line in the SOLE pane of a tmux
#     window, refuses to exit and shows how to close deliberately (`exit` or
#     prefix-x); everywhere else (multi-pane, no tmux) it exits as usual. No
#     single keystroke closes the last pane, so a stray or double Ctrl+D can't.
#     No in-widget y/n `read` either: its prompt paints a keystroke late and the
#     answer leaks onto the command line.
#
# Verify in a fresh shell: `bindkey '^D'` prints `"^D" _guard_ctrl_d`.
# ~/.config/zsh/tests/portability.test.zsh pins that the option and widget load.
setopt ignore_eof

_guard_ctrl_d() {
  if [[ -n $BUFFER ]]; then            # non-empty line: normal delete/list
    zle delete-char-or-list
    return
  fi
  if [[ -n $TMUX && "$(tmux display -p '#{window_panes}')" == 1 ]]; then
    # Last pane: refuse the bare Ctrl+D so the window survives. No read; the
    # message just paints (it's the next redraw) and we return.
    zle -M "Last pane in this tmux window — type 'exit' or prefix-x to close it."
    return
  fi
  exit                                 # multi-pane or no tmux: exit normally
}
zle -N _guard_ctrl_d

# Bind once, from a one-shot precmd hook, so the binding lands after every
# plugin: oh-my-zsh runs `bindkey -e` when sourced (below), making emacs the
# active keymap despite `set -o vi` above, so a ^D bound at this point in
# viins/vicmd would sit in an inactive keymap. Bind in every keymap, for both
# the raw C0 byte (Ghostty's usual Ctrl+D) and the CSI-u form (sent after a
# TUI exits without popping the Kitty keyboard protocol). The CSI-u
# Ctrl+C/Ctrl+L binds below share the keymap trap; if they misbehave in emacs
# mode, bind them here.
_guard_ctrl_d_bind() {
  local m
  for m in emacs viins vicmd; do
    bindkey -M $m '^D'        _guard_ctrl_d
    bindkey -M $m '\e[100;5u' _guard_ctrl_d
  done
  add-zsh-hook -d precmd _guard_ctrl_d_bind   # one-shot
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _guard_ctrl_d_bind
# ────────────────────────────────────────────────────────────────────────────

# Handle CSI u (Kitty Keyboard Protocol) encoded Ctrl keys.
# When a TUI exits without popping KKP, Ghostty sends CSI u sequences
# instead of raw C0 bytes. Zsh 5.9 can't decode these natively,
# so we bind the CSI u forms explicitly. Format: \e[<codepoint>;<modifier>u
# Modifier 5 = Ctrl. Ctrl+L/Ctrl+D are also forced via Ghostty text: keybinds.
bindkey -M viins '\e[99;5u'  send-break     # Ctrl+C (CSI u)
bindkey -M vicmd '\e[99;5u'  send-break     # Ctrl+C (CSI u)
bindkey -M viins '\e[108;5u' clear-screen   # Ctrl+L (CSI u)
bindkey -M vicmd '\e[108;5u' clear-screen   # Ctrl+L (CSI u)
# (Ctrl+D is handled by the guard block above, bound from a precmd hook.)

# Reduce vi mode key timeout (default 400ms eats characters after Esc/Ctrl sequences)
KEYTIMEOUT=10

# --------------------------------------------------------------------
# 2. ENVIRONMENT VARIABLES
# Shared by every machine: set a tool's variables only where the tool is
# installed, never by machine name (docs/zsh.md § Machines).
# --------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
export VISUAL="nvim"
export EDITOR="nvim"

# GCP — only where gcloud is installed
if (( $+commands[gcloud] )); then
  export CLOUDSDK_PYTHON="/opt/homebrew/bin/python3.14"
  export USE_GKE_GCLOUD_AUTH_PLUGIN=True
fi

# Bun
export BUN_INSTALL="$HOME/.bun"

# Misc
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export ALLOW_PLAINTEXT_LISTENER=yes
export K9S_CONFIG_DIR="$HOME/.config/k9s"
export COREPACK_ENABLE_AUTO_PIN=0
export DISABLE_AUTO_TITLE=true

# Claude Code
export CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1
export ENABLE_LSP_TOOLS=1

# Secrets
[ -f ~/.secrets ] && source ~/.secrets

# --------------------------------------------------------------------
# 3. OH-MY-ZSH
# --------------------------------------------------------------------
ZSH_THEME=""
plugins=(history zsh-autosuggestions)

# One fpath in every context, or oh-my-zsh deletes and rebuilds the completion
# dump (200-350 ms) whenever it differs from the recorded one. `brew shellenv` in
# ~/.zprofile exports FPATH, so without this a child shell inherits oh-my-zsh's
# entries and adds them again. Drop inherited oh-my-zsh entries, pin the two
# directories that only login shells add, and keep FPATH out of the
# environment. docs/zsh.md § Completion dump.
typeset -gU fpath
fpath=(/opt/homebrew/share/zsh/site-functions(N/) ${fpath:#$ZSH/*} $HOME/.orbstack/shell/completions/zsh(N/))
typeset +x FPATH

# Bind autosuggestion widgets once, at the first prompt, instead of rebinding
# every widget before every prompt. Safe while every widget exists by then:
# zsh-syntax-highlighting hooks zle-line-pre-redraw rather than wrapping
# widgets, and fzf, Oh My Posh and this file define theirs at startup.
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

source "$ZSH/oh-my-zsh.sh"

# --------------------------------------------------------------------
# 4. TOOL INIT (order matters — oh-my-posh must be last)
# --------------------------------------------------------------------
source "$HOME/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Register git.zsh completions (compdef needs compinit, set up by oh-my-zsh
# above). git.zsh itself is already sourced once by .zshenv's *.zsh glob.
_git_zsh_register_completions

# nvm — lazy-loaded. toolchain.zsh resolved the default Node into $NVM_BIN;
# re-apply the shared tool paths after login-shell and plugin setup, which
# can reorder PATH. Only `nvm` itself is deferred (~200ms saved).
[ -f "$HOME/.config/zsh/toolchain.zsh" ] && source "$HOME/.config/zsh/toolchain.zsh"
# Homebrew's nvm where it is installed, else nvm's own installer's copy.
nvm() {
  unfunction nvm
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s /opt/homebrew/opt/nvm/nvm.sh ]]; then
    . /opt/homebrew/opt/nvm/nvm.sh
    [ -s /opt/homebrew/opt/nvm/etc/bash_completion.d/nvm ] \
      && . /opt/homebrew/opt/nvm/etc/bash_completion.d/nvm
  else
    . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  fi
  nvm "$@"
}

# fzf
source <(fzf --zsh)

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# zoxide (directory jumping)
eval "$(zoxide init zsh)"

# Google Cloud SDK
[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ] && source "$HOME/google-cloud-sdk/completion.zsh.inc"

# oh-my-posh (must be last — other tools can override shell integration)
eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/zen.omp.json)"

# Register after the prompt hooks: Oh My Posh consumes the command's exit status
# before cout finalizes the execution record.
_cout_setup

# --------------------------------------------------------------------
# 5. ALIASES
# Aliases live in ~/.config/zsh/aliases.zsh (auto-sourced by .zshenv).
# Add new aliases there, not here.
# --------------------------------------------------------------------
# Planlab Bedrock creds for the agent eval. Exports AWS_ACCESS_KEY_ID /
# AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN from the pl-bedrock profile
# so the @ai-sdk/amazon-bedrock provider (which doesn't read profiles)
# can authenticate. Refresh by re-pasting temp creds from the SSO
# portal's Access keys panel for planlab-ci → BedrockTokenGenerator.
pl-bedrock() {
  if ! aws configure export-credentials --profile pl-bedrock --format env >/dev/null 2>&1; then
    echo "pl-bedrock: profile not found or temp creds expired" >&2
    echo "  refresh from SSO portal → planlab-ci → BedrockTokenGenerator → Access keys" >&2
    return 1
  fi
  eval "$(aws configure export-credentials --profile pl-bedrock --format env)"
  echo "pl-bedrock: Bedrock creds loaded into shell"
}

# git() — the branch-creation guard and planlab's push --no-verify — lives in
# ~/.config/zsh/git.zsh. Don't define another git() here: it would replace that
# one in every interactive shell.
