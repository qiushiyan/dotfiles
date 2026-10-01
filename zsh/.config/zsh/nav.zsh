# ~/.config/zsh/nav.zsh
# Navigation utility functions

# --------------------------------------------------------------------
# n - Open file/directory in neovim
# --------------------------------------------------------------------
n() {
  local parent_dir file_name
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
# _pull_both - Run pulls here and in the other machine's copies, at once
# --------------------------------------------------------------------
# Takes (label, dir, cmd) triples and runs every cmd in its dir on both
# machines. The laptop and the mini keep their own clones at the same
# $HOME-relative paths (docs/qiushi-mini.md § planlab checkout). The mini is
# the machine where $USER is qiushiyan, and it reaches the laptop as
# qiushi-mac. All pulls run in parallel with output buffered, then print
# local first, each repo under its label; the clones are independent, so one
# failing doesn't stop the others. Buffered output would hide a prompt, so
# git may not ask for credentials or a merge message and ssh may not ask for
# anything.
_pull_both() {
  emulate -L zsh
  setopt no_monitor
  local here=laptop there=mini host=${MINI_HOST:-qiushi-mini}
  [[ $USER == qiushiyan ]] && here=mini there=laptop host=qiushi-mac
  local quiet='export GIT_TERMINAL_PROMPT=0 GIT_MERGE_AUTOEDIT=no'
  local out=$(mktemp -d "${TMPDIR:-/tmp}/pull-both.XXXXXX")
  local label dir cmd side i=0 rc=0
  local -a labels
  local -A pid
  {
    for label dir cmd in "$@"; do
      (( ++i ))
      labels+=($label)
      (eval "$quiet"; cd -- "$dir" && eval "$cmd") </dev/null >$out/here.$i 2>&1 &
      pid+=(here.$i $!)
      ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$host" \
        "$quiet; cd ~/${dir#$HOME/} && $cmd" >$out/there.$i 2>&1 &
      pid+=(there.$i $!)
    done
    for side in here there; do
      print -P "%F{blue}${(P)side}%f"
      for i in {1..$#labels}; do
        print -P "%F{8}${labels[i]}%f"
        wait $pid[$side.$i] || rc=1
        command cat $out/$side.$i
      done
    done
  } always {
    command rm -rf -- $out
  }
  return rc
}

# --------------------------------------------------------------------
# p / pp - Jump to the planlab checkout; pp pulls it and its briefs
# --------------------------------------------------------------------
# Functions rather than aliases so the path lives in one place and `p` can
# take a subpath (`p apps/web`). `pp` pulls the checkout and planlab's
# handoff briefs on both machines, from anywhere, all four in parallel. The
# checkout pulls whatever branch it is on, passing pp's arguments to
# `git pull`. The briefs clone tracks main only, so a briefs checkout on any
# other branch is an error rather than a pull. `pp --cd` then enters the
# checkout, even after a failed pull, and keeps the pull's status. `pp` shadows Homebrew nss's
# certificate printer; `command pp` still reaches it.
: ${PLANLAB_DIR:=$HOME/dev/planlab/main}
: ${PLANLAB_HANDOFFS_DIR:=$HOME/dev/.handoffs/planlab-main}

p() {
  emulate -L zsh
  cd -- "$PLANLAB_DIR/${1:-}"
}

pp() {
  emulate -L zsh
  local enter=${@[(Ie)--cd]} rc=0
  (( enter )) && argv[enter]=()
  _pull_both \
    planlab "$PLANLAB_DIR" "git pull ${(j: :)${(q)@}}" \
    handoffs "$PLANLAB_HANDOFFS_DIR" \
    'test "$(git branch --show-current)" = main || { echo "not on main" >&2; exit 1; }; git pull --ff-only origin main' \
    || rc=$?
  (( enter )) && cd -- "$PLANLAB_DIR"
  return rc
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
