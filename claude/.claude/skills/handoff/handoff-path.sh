#!/usr/bin/env bash
# Resolve a handoff baton's path.
#
#   handoff-path.sh           -> this project's baton folder
#   handoff-path.sh <slug>    -> the baton file for <slug>; creates its folder
#
# Batons are grouped by project: ~/dev/.handoffs/<project>/<slug>.md. <project>
# is the checkout's path under ~/dev with "/" flattened to "-", so a repo nested
# at planlab/main files under planlab-main/ instead of a bare main/ that every
# such project would collide in. Derived from --git-common-dir, so a linked
# worktree reports its main checkout's name rather than the branch directory.
set -euo pipefail

if ! common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  echo "handoff-path: not inside a git repository — cd to the project first." >&2
  exit 1
fi

root=$(dirname "$common")
case $root in
  "$HOME"/dev/*) rel=${root#"$HOME"/dev/} ;;
  "$HOME"/*)     rel=${root#"$HOME"/} ;;
  *)             rel=$(basename "$(dirname "$root")")/$(basename "$root") ;;
esac
dir="$HOME/dev/.handoffs/${rel//\//-}"

if [ $# -eq 0 ]; then
  printf '%s\n' "$dir"
else
  file="$dir/$1.md"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$file"
fi
