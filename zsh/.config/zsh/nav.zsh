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
# p / pp - Jump to the planlab checkout; pp pulls it and its briefs
# --------------------------------------------------------------------
# Functions rather than aliases so the path lives in one place and `p` can
# take a subpath (`p apps/web`). `pp` fast-forwards the checkout and
# planlab's handoff briefs on both machines, from anywhere, through
# `twin repos pull --both`: each machine pulls its own clone and reports
# for itself, and one refusing (uncommitted work, a diverged branch) does
# not stop the other. The briefs clone tracks main only, which the manifest
# holds (`branch = "main"` in ~/.config/twin/twin.toml). `pp --cd` then
# enters the checkout, even after a refused pull, and keeps the pull's
# status. `pp` shadows Homebrew nss's certificate printer; `command pp`
# still reaches it.
: ${PLANLAB_DIR:=$HOME/dev/planlab/main}

p() {
  emulate -L zsh
  cd -- "$PLANLAB_DIR/${1:-}"
}

pp() {
  emulate -L zsh
  local enter=${@[(Ie)--cd]} rc=0
  (( enter )) && argv[enter]=()
  twin repos pull planlab planlab-handoffs --both "$@" || rc=$?
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
