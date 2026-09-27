# ~/.config/zsh/nav.zsh
# Navigation utility functions

# --------------------------------------------------------------------
# n - Open file/directory in neovim
# --------------------------------------------------------------------
n() {
  if [ $# -eq 0 ]; then
    nvim .
  else
    if [ -d "$1" ]; then
      cd "$1" && nvim .
    elif [ -f "$1" ]; then
      parent_dir=$(dirname "$1")
      file_name=$(basename "$1")
      cd "$parent_dir" && nvim "$file_name"
    else
      echo "Error: $1 is not a valid file or directory"
      return 1
    fi
  fi
}

# --------------------------------------------------------------------
# take - Create directory and cd into it
# --------------------------------------------------------------------
take() {
  if [[ -z "$1" ]]; then
    echo "usage: take <directory>" >&2
    return 1
  fi
  mkdir -p -- "$1" && cd -- "$1"
}

# --------------------------------------------------------------------
# drop - Delete current directory and cd to parent (reverse of take)
# --------------------------------------------------------------------
drop() {
  local force=false
  [[ "$1" == "-f" ]] && force=true

  local current="$PWD"
  local name="${current:t}"

  if [[ "$current" == "/" || "$current" == "$HOME" || "$current" == "$HOME/"* && "${current#$HOME/}" != */* ]]; then
    echo "drop: refusing to delete $current" >&2
    return 1
  fi

  local contents
  contents=$(ls -A "$current" 2>/dev/null)

  if ! $force; then
    if [[ -n "$contents" ]]; then
      echo "Directory '$name' contains:"
      ls -A "$current"
      echo ""
    fi
    echo -n "Delete '$name' and return to parent? [y/N] "
    read -r response
    [[ ! "$response" =~ ^[Yy]$ ]] && echo "Aborted." && return 1
  fi

  cd -- .. && rm -rf -- "$current"
}

# --------------------------------------------------------------------
# _pull_both - Run a pull here and in the other machine's copy, at once
# --------------------------------------------------------------------
# The laptop and the mini keep their own clones at the same $HOME-relative
# paths (docs/qiushi-mini.md § planlab checkout). The mini is the machine
# where $USER is qiushiyan, and it reaches the laptop as qiushi-mac. Both
# pulls run in parallel with output buffered, then print local first; the
# clones are independent, so one failing doesn't stop the other. Buffered
# output would hide a prompt, so git may not ask for credentials or a merge
# message and ssh may not ask for anything.
_pull_both() {
  emulate -L zsh
  setopt no_monitor
  local dir=$1 cmd=$2 rel=${1#$HOME/} here=laptop there=mini
  local host=${MINI_SYNC_HOST:-qiushi-mini}
  [[ $USER == qiushiyan ]] && here=mini there=laptop host=qiushi-mac
  local quiet='export GIT_TERMINAL_PROMPT=0 GIT_MERGE_AUTOEDIT=no'
  local out=$(mktemp -d "${TMPDIR:-/tmp}/pull-both.XXXXXX") pid rc=0
  {
    (eval "$quiet"; cd -- "$dir" && eval "$cmd") </dev/null >$out/here 2>&1 &
    pid=$!
    ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$host" \
      "$quiet; cd ~/$rel && $cmd" >$out/there 2>&1 &
    print -P "%F{blue}$here%f"
    wait $pid || rc=1
    command cat $out/here
    print -P "%F{blue}$there%f"
    wait $! || rc=1
    command cat $out/there
  } always {
    command rm -rf -- $out
  }
  return rc
}

# --------------------------------------------------------------------
# p / pp - Jump to the planlab checkout; pp pulls it on both machines
# --------------------------------------------------------------------
# Functions rather than aliases so the path lives in one place and `p` can
# take a subpath (`p apps/web`). `pp` pulls whatever branch each checkout
# is on, from anywhere, passing its arguments to `git pull`. `pp` shadows
# Homebrew nss's certificate printer; `command pp` still reaches it.
: ${PLANLAB_DIR:=$HOME/dev/planlab/main}

p() {
  emulate -L zsh
  cd -- "$PLANLAB_DIR/${1:-}"
}

pp() {
  emulate -L zsh
  _pull_both "$PLANLAB_DIR" "git pull ${(j: :)${(q)@}}"
}

# --------------------------------------------------------------------
# ph - Pull planlab's handoff briefs on both machines
# --------------------------------------------------------------------
# The briefs clone tracks main only, so a checkout on any other branch is
# an error rather than a pull.
: ${PLANLAB_HANDOFFS_DIR:=$HOME/dev/.handoffs/planlab-main}

ph() {
  emulate -L zsh
  _pull_both "$PLANLAB_HANDOFFS_DIR" \
    'test "$(git branch --show-current)" = main || { echo "not on main" >&2; exit 1; }; git pull --ff-only origin main'
}

# --------------------------------------------------------------------
# y - Yazi file manager with directory tracking
# --------------------------------------------------------------------
y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# --------------------------------------------------------------------
# fcd - Fuzzy cd using z history
# --------------------------------------------------------------------
fcd() {
  local dir
  dir=$(cat ~/.z | cut -d'|' -f1 | fzf --tac --no-sort) && cd "$dir"
}
