#!/usr/bin/env bash
# Resolve a handoff baton's path:  handoff-path.sh <slug>
#
# Batons are grouped by project: ~/dev/.handoffs/<project>/<slug>.md. <project>
# is the checkout's path under ~/dev with "/" flattened to "-", so a repo nested
# at planlab/main files under planlab-main/ instead of a bare main/ that every
# such project would collide in. A slug carrying the branch's own "/" nests, the
# way ~/dev/.worktrees/<project>/feat/login does.
#
# Which directory names the project depends on the checkout kind, and the two
# git queries disagree by design:
#   - ordinary checkout, including a submodule -> --show-toplevel, the checkout
#     root. Its --git-common-dir points into the superproject's .git/modules,
#     which names the project after git's storage layout.
#   - linked worktree -> the main checkout, via --git-common-dir. Its
#     --show-toplevel is the branch directory, which names the project after
#     the branch.
# A worktree is what makes the two differ, so that comparison picks the query.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: handoff-path.sh <slug>" >&2
  exit 2
fi

if ! common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  echo "handoff-path: not inside a git repository — cd to the project first." >&2
  exit 1
fi

if [ "$(git rev-parse --path-format=absolute --git-dir)" = "$common" ]; then
  if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
    echo "handoff-path: no working tree here — cd to a checkout, not a bare repository." >&2
    exit 1
  fi
else
  root=$(dirname "$common")
fi

# git reports a physical path; $HOME may be a logical one (on macOS /var is a
# symlink to /private/var). Compare like with like, or a repo under a symlinked
# parent misses the dev root and gets named from the fallback instead.
home=$(cd "$HOME" && pwd -P)
root=$(cd "$root" && pwd -P)

case $root in
  "$home"/dev/*) rel=${root#"$home"/dev/} ;;
  "$home"/*)     rel=${root#"$home"/} ;;
  *)             rel=$(basename "$(dirname "$root")")/$(basename "$root") ;;
esac

file="$HOME/dev/.handoffs/${rel//\//-}/$1.md"
mkdir -p "$(dirname "$file")"
printf '%s\n' "$file"
