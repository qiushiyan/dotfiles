# ~/.config/zsh/aliases.zsh
# All shell aliases, grouped by purpose.
# Auto-sourced by .zshenv via ~/.config/zsh/*.zsh glob.

# --------------------------------------------------------------------
# Editors & Config
# --------------------------------------------------------------------
alias zshconfig="cd ~/dotfiles/zsh && nvim ."
alias nvimconfig="cd ~/.config/nvim && nvim ."
alias ghosttyconfig="nvim ~/.config/ghostty/config"
alias tmuxconfig="nvim ~/.config/tmux/tmux.conf"
alias zedconfig="zed ~/.config/zed"
alias sshconfig="nvim ~/.ssh/config"
alias ttconfig="nvim ~/.config/tabtype/config.json"
alias gitconfig="git config --global --edit"
alias ohmyzsh="code ~/.oh-my-zsh"
alias cspellconfig="code ~/.cspell/custom-dictionary-user.txt"
alias zshreload="source ~/.zshenv && source ~/.zshrc"

# --------------------------------------------------------------------
# Git
# --------------------------------------------------------------------
alias lg="lazygit"
alias gsp='git stash -p'

# Quick commit and push (pass message as arg, defaults to 'update')
function gg { git add . && git commit -m "${1:-update}" && git push; }

# --------------------------------------------------------------------
# Kubernetes & Docker
# --------------------------------------------------------------------
alias k=kubectl
alias kb=kubectl
alias kk=k9s
alias kk-production='k9s --context listenhub-production'
alias kk-staging='k9s --context listenhub-staging'
alias dk="docker"
alias dkb="docker build"
alias dkc="docker-compose"

# --------------------------------------------------------------------
# Python
# --------------------------------------------------------------------
alias python="/opt/homebrew/bin/python3.14"
alias python3="/opt/homebrew/bin/python3.14"

# --------------------------------------------------------------------
# R (uncomment if needed)
# --------------------------------------------------------------------
# alias R='command R --no-save --no-restore'
# alias r='radian --no-save --no-restore'
# alias rlib=/Library/Frameworks/R.framework/Versions/4.1-arm64/Resources/library
# alias rstudio="open -na Rstudio"

# --------------------------------------------------------------------
# Navigation & Files
# --------------------------------------------------------------------
alias workspace='cd ~/workspace'
alias l='gls --color -lhF --group-directories-first'
alias bat="bat --tabs 4 --paging=never"
alias scripts="cat package.json | jq --color-output '.scripts'"

# --------------------------------------------------------------------
# Dev Scripts & SSH
# --------------------------------------------------------------------
alias devitell="~/.config/scripts/dev-itell.sh"
alias devmanager="~/.config/scripts/dev-marswave-manager.sh"
alias devengine="~/.config/scripts/dev-marswave-engine.sh"
alias sshstaging="ssh marswave.staging"
alias sshprod="ssh marswave.production"

# --------------------------------------------------------------------
# Misc Tools
# --------------------------------------------------------------------
alias c="cursor"
alias o="openclaw"
alias ct="count-token"
alias make="mmake"                   # https://github.com/tj/mmake
alias tsx='tsx --no-warnings'
alias -s ts='bun'                    # suffix: *.ts files run with bun
alias -s git="git clone"             # suffix: *.git URLs auto-clone
