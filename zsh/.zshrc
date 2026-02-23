# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --------------------------------------------------------------------
# 1. SHELL BEHAVIOR & HISTORY (Added new settings here)
# --------------------------------------------------------------------
set -o vi
HISTSIZE=100000
SAVEHIST=100000
# Allows you to use 'v' in vi-mode to open the current command in Neovim
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# --------------------------------------------------------------------
# 2. PATHS & ENV VARS
# --------------------------------------------------------------------
export PATH="$PATH:/Contents/Resources/app/bin:$HOME/bin:$HOME/bin/elixir-ls:/usr/local/bin:$HOME/Library/Python/3.9/bin:/Users/qiushi/Library/Python/3.10/bin:/opt/homebrew/opt/openjdk@11/bin:/Users/qiushi/Library/Android/sdk/platform-tools:$HOME/.mix/escripts:/opt/homebrew/opt/node@16/bin/:/Users/qiushi/.local/bin:"

export ZSH="/Users/qiushi/.oh-my-zsh"
export VISUAL="nvim"
export EDITOR='nvim'
export AWS_PROFILE=marswave
export CLOUDSDK_PYTHON="/opt/homebrew/bin/python3.10"
export CONDA_AUTO_ACTIVATE_BASE=false

# Theme
# ZSH_THEME="spaceship"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(history zsh-autosuggestions git) # Added 'git' plugin for better completions

# --------------------------------------------------------------------
# 3. OH-MY-ZSH INIT
# --------------------------------------------------------------------
source $ZSH/oh-my-zsh.sh
source /Users/qiushi/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.8
export SPARK_HOME=/Users/qiushi/spark/spark-3.1.2-bin-hadoop3.2
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES


# --------------------------------------------------------------------
# 4. CUSTOM FUNCTIONS (moved to ~/.zshenv for non-interactive availability)
# Re-source git.zsh to register completions (compdef requires compinit from oh-my-zsh above)
# --------------------------------------------------------------------
source ~/.config/zsh/git.zsh

# --------------------------------------------------------------------
# 5. ALIASES
# --------------------------------------------------------------------
alias k=kubectl
alias kb=kubectl
alias kk=k9s
alias kk-production='k9s --context listenhub-production'
alias kk-staging='k9s --context listenhub-staging'

# NEW: Git interactive stash
alias gsp='git stash -p'

alias -s ts='bun'
alias -s git="git clone"
alias gg="git add . && git commit -m 'update' && git push"
alias zshconfig="nvim ~/.zshrc"
alias ttconfig="nvim ~/.config/tabtype/config.json"
alias zedconfig="zed ~/.config/zed"
alias sshconfig="nvim ~/.ssh/config"
alias c="cursor"
alias tmuxconfig="nvim ~/.config/tmux/tmux.conf"
alias zshreload="source ~/.zshenv && source ~/.zshrc"
alias gitconfig="git config --global --edit"
alias nvimconfig="cd ~/.config/nvim && nvim ."
alias ghosttyconfig="nvim ~/.config/ghostty/config"
alias ohmyzsh="code ~/.oh-my-zsh"
alias python="/opt/homebrew/bin/python3.10"
alias python3="/opt/homebrew/bin/python3.10"
alias scripts="cat package.json | jq --color-output '.scripts'"
alias devitell="~/.config/scripts/dev-itell.sh"
alias devmanager="~/.config/scripts/dev-marswave-manager.sh"
alias devengine="~/.config/scripts/dev-marswave-engine.sh"
alias sshstaging="ssh marswave.staging"
alias sshprod="ssh marswave.production"

export PATH="$HOME/.config/tmux/plugins/tmuxifier/bin:$PATH"
eval "$(tmuxifier init -)"
export PATH="$(gem environment gemdir)/bin:$PATH"


DISABLE_AUTO_TITLE=true

export PYSPARK_PYTHON="/opt/homebrew/bin/python3.10"
export PYSPARK_DRIVER_PYTHON="/opt/homebrew/bin/python3.10"
export PIPX_DEFAULT_PYTHON="python3.10"

alias lg="lazygit"

alias rstudio="open -na Rstudio"
alias workspace='cd ~/workspace'
alias R="$(which R) --no-save --no-restore"
alias r="$(which radian) --no-save --no-restore"
alias rlib=/Library/Frameworks/R.framework/Versions/4.1-arm64/Resources/library
alias l='gls --color -lhF --group-directories-first'
alias bat="bat --tabs 4 --paging=never"
# use this version of make https://github.com/tj/mmake
alias make="mmake"
# docker aliases
alias dk="docker"
alias dkb="docker build"
alias dkc="docker-compose"




# cspell
alias cspellconfig="code ~/.cspell/custom-dictionary-user.txt"

# pandoc
export RSTUDIO_PANDOC="/Applications/RStudio.app/Contents/MacOS/quarto/bin/tools"

export CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1
export SMART_SUGGESTION_AI_PROVIDER=gemini
export GEMINI_MODEL="gemini-2.5-flash"

export GOOGLE_GENAI_USE_VERTEXAI=true
export GOOGLE_CLOUD_PROJECT='marswave'
export GOOGLE_CLOUD_LOCATION='us-west1'
# claude code
export ENABLE_LSP_TOOLS=1
# Secrets (API keys, tokens, etc.) - loaded from ~/.secrets
[ -f ~/.secrets ] && source ~/.secrets

# kafka
export ALLOW_PLAINTEXT_LISTENER=yes

# include z command for quick navigation
source /opt/homebrew/etc/profile.d/z.sh


# quarto
export QUARTO_PYTHON=/opt/homebrew/bin/python3.10

# android sdk
export ANDROID_SDK=/Users/qiushi/Library/Android/sdk

# hdf5
export HDF5_DIR="$(brew --prefix hdf5)"

# starship
eval "$(starship init zsh)"

# mcfly
# eval "$(mcfly init zsh)"
# export MCFLY_FUZZY=2
# export MCFLY_RESULTS=20
# export MCFLY_INTERFACE_VIEW=BOTTOM
# export MCFLY_RESULTS_SORT=LAST_RUN


export LLVM_CONFIG="/opt/homebrew/opt/llvm@11/bin/llvm-config"

# nvm
# export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"                                       # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion


export WASMTIME_HOME="$HOME/.wasmtime"

export PATH="$WASMTIME_HOME/bin:$PATH"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias tsx=tsx --no-warnings

export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"


# bun completions
[ -s "/Users/qiushi/.bun/_bun" ] && source "/Users/qiushi/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"


# proxy settings
# export http_proxy=http://127.0.0.1:7899
# export https_proxy=http://127.0.0.1:7899
# export NO_PROXY="/var/run/docker.sock"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export K9S_CONFIG_DIR="$HOME/.config/k9s"

[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


export nvm_default_version=22


source <(fzf --zsh)
# export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git --no-ignore-vcs "\.env$|^[^.]"'

# Smart Suggestion # smart-suggestion
source /Users/qiushi/.config/smart-suggestion/smart-suggestion.plugin.zsh # smart-suggestion

# Google Cloud SDK
# (We hardcode the path to avoid lag and point to the new location)
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then
    source "$HOME/google-cloud-sdk/path.zsh.inc"
fi

if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
    source "$HOME/google-cloud-sdk/completion.zsh.inc"
fi

# Use corepack for pnpm (respects packageManager field in package.json)
export COREPACK_ENABLE_AUTO_PIN=0

