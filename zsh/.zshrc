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

# ── Ctrl+D guard ──────────────────────────────────────  docs/ctrl-d-guard.md
# An accidental Ctrl+D must never silently close the last pane of a tmux window
# (losing e.g. a Claude Code session). Two layers, robust against keymap and
# plugin load order:
#
#   Floor — `setopt ignore_eof`: keymap-/plugin-independent. An empty-line EOF
#     can no longer exit zsh on its own, whatever ^D happens to be bound to.
#   UX — a widget on ^D that, on an empty line in the SOLE pane of a tmux
#     window, refuses to exit and shows how to close deliberately; everywhere
#     else (multi-pane, no tmux) it exits as usual. No in-widget `read` — that
#     was fragile (message painted late, keypress leaked to the command line).
#     It is (re)bound from a precmd hook (below) so it runs AFTER oh-my-zsh's
#     `bindkey -e`, fzf, smart-suggestion, etc. — and in every keymap.
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

# Bind once, after all plugins have loaded, in every keymap, for both the raw
# C0 byte and Ghostty's CSI-u form. (oh-my-zsh runs `bindkey -e` at source time
# — .zshrc:~140 — which is why binding earlier in viins/vicmd did nothing.)
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
# 2. PATH (all additions in one place)
# --------------------------------------------------------------------
export PATH="\
$HOME/.config/tmux/plugins/tmuxifier/bin:\
$HOME/.wasmtime/bin:\
$HOME/.bun/bin:\
$HOME/bin:\
$HOME/bin/elixir-ls:\
$HOME/.local/bin:\
$HOME/.mix/escripts:\
/opt/homebrew/opt/postgresql@16/bin:\
/opt/homebrew/opt/openjdk@11/bin:\
/usr/local/bin:\
$HOME/Library/Android/sdk/platform-tools:\
$PATH"

# --------------------------------------------------------------------
# 3. ENVIRONMENT VARIABLES
# --------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
export VISUAL="nvim"
export EDITOR="nvim"

# AWS / GCP
# export AWS_PROFILE=marswave
export CLOUDSDK_PYTHON="/opt/homebrew/bin/python3.14"
export GOOGLE_GENAI_USE_VERTEXAI=true
export GOOGLE_CLOUD_PROJECT="marswave"
export GOOGLE_CLOUD_LOCATION="us-west1"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

# Java / Android
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.8
export ANDROID_SDK="$HOME/Library/Android/sdk"

# Python
export CONDA_AUTO_ACTIVATE_BASE=false
export PYSPARK_PYTHON="/opt/homebrew/bin/python3.14"
export PYSPARK_DRIVER_PYTHON="/opt/homebrew/bin/python3.14"
export PIPX_DEFAULT_PYTHON="python3.14"
export QUARTO_PYTHON="/opt/homebrew/bin/python3.14"

# Spark
export SPARK_HOME="$HOME/spark/spark-3.1.2-bin-hadoop3.2"

# Bun
export BUN_INSTALL="$HOME/.bun"

# Wasmtime
export WASMTIME_HOME="$HOME/.wasmtime"

# Misc
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export RSTUDIO_PANDOC="/Applications/RStudio.app/Contents/MacOS/quarto/bin/tools"
export ALLOW_PLAINTEXT_LISTENER=yes
export K9S_CONFIG_DIR="$HOME/.config/k9s"
export COREPACK_ENABLE_AUTO_PIN=0
export DISABLE_AUTO_TITLE=true

# Claude Code
export CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1
export ENABLE_LSP_TOOLS=1

# AI suggestions
export SMART_SUGGESTION_AI_PROVIDER=gemini
export GEMINI_MODEL="gemini-2.5-flash"

# Secrets
[ -f ~/.secrets ] && source ~/.secrets

# --------------------------------------------------------------------
# 4. OH-MY-ZSH
# --------------------------------------------------------------------
ZSH_THEME=""
plugins=(history zsh-autosuggestions git)
source "$ZSH/oh-my-zsh.sh"
unalias gg 2>/dev/null   # git plugin sets gg='git gui citool'; we define our own in aliases.zsh

# --------------------------------------------------------------------
# 5. TOOL INIT (order matters — oh-my-posh must be last)
# --------------------------------------------------------------------
source "$HOME/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Register git.zsh completions (compdef needs compinit, set up by oh-my-zsh
# above). git.zsh itself is already sourced once by .zshenv's *.zsh glob.
_git_zsh_register_completions

# tmuxifier
eval "$(tmuxifier init -)"

# nvm — lazy-loaded. toolchain.zsh resolved the default Node into $NVM_BIN;
# re-assert it at the front of PATH here, since Homebrew's shellenv (run from
# .zprofile, after toolchain.zsh) would otherwise let an unrelated Homebrew
# `node` shadow it. Only the `nvm` command itself is deferred (~200ms saved).
[[ -n "$NVM_BIN" ]] && path=("$NVM_BIN" $path)
nvm() {
  unfunction nvm
  . /opt/homebrew/opt/nvm/nvm.sh
  [ -s /opt/homebrew/opt/nvm/etc/bash_completion.d/nvm ] \
    && . /opt/homebrew/opt/nvm/etc/bash_completion.d/nvm
  nvm "$@"
}

# fzf
source <(fzf --zsh)

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# zoxide (directory jumping)
eval "$(zoxide init zsh)"

# Google Cloud SDK
[ -f "$HOME/google-cloud-sdk/path.zsh.inc" ] && source "$HOME/google-cloud-sdk/path.zsh.inc"
[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ] && source "$HOME/google-cloud-sdk/completion.zsh.inc"

# smart-suggestion
source "$HOME/.config/smart-suggestion/smart-suggestion.plugin.zsh"

# oh-my-posh (must be last — other tools can override shell integration)
eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/zen.omp.json)"

# --------------------------------------------------------------------
# 6. ALIASES
# Aliases live in ~/.config/zsh/aliases.zsh (auto-sourced by .zshenv).
# Add new aliases there, not here.
# --------------------------------------------------------------------

# pnpm
export PNPM_HOME="/Users/qiushi/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

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

# Default `git push` to --no-verify inside the planlab/main clone (and all its
# worktrees), bypassing the git-lfs pre-push upload hook. Safe for everyday
# commits that don't touch LFS-tracked binaries (png/svg/xml/xer/pdf/...); when
# you DO change an asset, run a real push with `command git push` (bypasses this
# function) or force the blobs with `git lfs push --all origin <branch>`.
# Keys off the shared common git dir so it matches the clone and any worktree,
# wherever the worktree lives. -ef compares inodes, so relative-vs-absolute
# paths still match. Only spawns a subprocess on `push`; every other git command
# short-circuits and runs untouched.
git() {
  if [[ "$1" == push ]] && \
     [[ "$(command git rev-parse --git-common-dir 2>/dev/null)" -ef "$HOME/dev/planlab/main/.git" ]]; then
    print -P "%F{242}↳ push --no-verify (skipping git-lfs pre-push)%f" >&2
    shift
    command git push --no-verify "$@"
  else
    command git "$@"
  fi
}
