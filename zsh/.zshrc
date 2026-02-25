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
/opt/homebrew/opt/node@16/bin:\
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
export nvm_default_version=22

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

# Re-source git.zsh to register completions (compdef needs compinit from oh-my-zsh)
source ~/.config/zsh/git.zsh

# tmuxifier
eval "$(tmuxifier init -)"

# nvm
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# fzf
source <(fzf --zsh)

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# z (directory jumping)
source /opt/homebrew/etc/profile.d/z.sh

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

# OpenClaw Completion
source "/Users/qiushi/.openclaw/completions/openclaw.zsh"
