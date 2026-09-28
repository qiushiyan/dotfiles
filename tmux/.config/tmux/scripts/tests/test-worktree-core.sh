#!/usr/bin/env bash
# test-worktree-core.sh — the pinned traps in worktree-core.sh's pure git logic.
#
# Usage: bash test-worktree-core.sh [W1 W5 ...]
#
# Scope is the tmux-FREE support the shell still owns: snapshots, recovery refs
# and their expiry, and removal's parent cleanup. Merge verdicts, the trunk, and
# its freshness belong to gwt and are tested in ~/dev/gwt. The popup's tmux glue
# needs a scratch server (tests/test-gwt-popup.py).
#
# ISOLATION. Worktree paths derive from $HOME/dev/.worktrees, so a case that ran
# against the real HOME would create worktrees inside the user's own store.
# Every case runs with HOME pointed at a sandbox; W12 asserts the real worktree
# store is untouched.

set -uo pipefail

CORE="$(cd "$(dirname "$0")/.." && pwd)/worktree-core.sh"
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/wt-core-test.XXXXXX")
REAL_WT="$HOME/dev/.worktrees"
REAL_BEFORE=$(ls -A "$REAL_WT" 2>/dev/null | sort)

cleanup() { rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ $# -eq 0 ] && return 0; case " $* " in *" $CASE "*) return 0;; esac; return 1; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export HOME="$SANDBOX"
export XDG_CONFIG_HOME="$SANDBOX/.config"
unset GWT_CONFIG
export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig"; : > "$GIT_CONFIG_GLOBAL"

# Run a core function inside a repo: C <repo> <fn> [args...]
C() { (cd "$1" && shift && source "$CORE" && "$@" 2>&1); }
# Same, reporting only the exit status — for the predicates.
Cq() { (cd "$1" && shift && source "$CORE" && "$@" >/dev/null 2>&1) && echo yes || echo no; }

# --- fixture: a repository with one tracked file --------------------------------

REPO="$SANDBOX/repo"
git init -q -b main "$REPO"
echo base > "$REPO/tracked.txt"
git -C "$REPO" add tracked.txt
git -C "$REPO" commit -qm init

# --- pre-deletion safety net ---------------------------------------------------

SNAP="$SANDBOX/dev/.worktrees/proj/snapme"
git -C "$REPO" worktree add -q "$SNAP" -b snapme main
printf 'tracked-edit\n' >> "$SNAP/tracked.txt"
printf 'brand new\n' > "$SNAP/untracked.txt"
printf 'ignored\n' > "$SNAP/ignore-me"
printf 'ignore-me\n' > "$SNAP/.gitignore"
SNAP_SHA=$(C "$SNAP" wt_snapshot_worktree "$SNAP" "test snapshot")

# W15  THE reason this isn't `git stash create`: a stash captures tracked
#      modifications only, and the dirt in an agent's worktree is mostly new
#      untracked files. Snapshotting those is the whole point.
CASE=W15; want "$@" && ok W15 "brand new" "$(git -C "$REPO" show "$SNAP_SHA:untracked.txt" 2>&1)"

# W16  Tracked edits ride along too.
CASE=W16; want "$@" && ok W16 yes "$(case "$(git -C "$REPO" show "$SNAP_SHA:tracked.txt" 2>&1)" in *tracked-edit*) echo yes;; *) echo no;; esac)"

# W17  ...but ignored paths do NOT. `add -A` obeys .gitignore, which is what
#      keeps a node_modules out of the snapshot (and the snapshot instant).
CASE=W17; want "$@" && ok W17 no "$(git -C "$REPO" cat-file -e "$SNAP_SHA:ignore-me" 2>/dev/null && echo yes || echo no)"

# W18  The worktree's own index is untouched — the snapshot builds its tree in a
#      scratch GIT_INDEX_FILE. Staging the user's files as a side effect would
#      corrupt the very state we're trying to preserve.
CASE=W18; want "$@" && ok W18 "?? untracked.txt" "$(git -C "$SNAP" status --porcelain | grep untracked)"

# W19  Two branches in one batch that flatten to the same ref path would
#      overwrite each other; `feat` and `feat/x` would collide outright as a
#      directory/file conflict in the ref store. The slot keeps them apart.
R1=$(C "$REPO" wt_backup_ref 1700000000.1 001 feat "$SNAP_SHA")
R2=$(C "$REPO" wt_backup_ref 1700000000.1 002 feat/x "$SNAP_SHA")
CASE=W19; want "$@" && ok W19 "refs/wt-trash/1700000000.1/001-feat refs/wt-trash/1700000000.1/002-feat-x" "$R1 $R2"

# W20  Old batches expire. Backup refs keep objects reachable forever, so a net
#      nobody prunes is an unbounded disk leak — same age gate as the trash dir.
C "$REPO" wt_backup_ref "$(date +%s).9" 001 recent "$SNAP_SHA" >/dev/null
C "$REPO" wt_prune_backups 30 >/dev/null
CASE=W20; want "$@" && ok W20 "1" "$(git -C "$REPO" for-each-ref --format='%(refname)' refs/wt-trash | wc -l | tr -d ' ')"

# W21  ...and 0 days must not be read as "expire everything now" — it's the
#      documented way to keep snapshots forever.
C "$REPO" wt_prune_backups 0 >/dev/null
CASE=W21; want "$@" && ok W21 "1" "$(git -C "$REPO" for-each-ref --format='%(refname)' refs/wt-trash | wc -l | tr -d ' ')"

# Placement slot checks live in ~/dev/gwt/internal/worktree/worktree_test.go.

# --- removal parent cleanup ---------------------------------------------------

# The old recursive find walked dependencies in every sibling worktree and
# deleted their empty directories. Exercise real rmdir against sandbox paths.
PARENTS="$SANDBOX/parent cleanup"
mkdir -p "$PARENTS/feat/nested" "$PARENTS/keep/node_modules/empty"
CASE=W36; if want "$@"; then
  C "$REPO" wt_remove_empty_parents "$PARENTS" "$PARENTS/feat/nested/removed"
  ok W36-ancestors-gone no "$([ -d "$PARENTS/feat" ] && echo yes || echo no)"
  ok W36-sibling-preserved yes "$([ -d "$PARENTS/keep/node_modules/empty" ] && echo yes || echo no)"
fi

CASE=W37; if want "$@"; then
  mkdir -p "$PARENTS/shared/remaining" "$PARENTS/shared/nested"
  C "$REPO" wt_remove_empty_parents "$PARENTS" "$PARENTS/shared/nested/removed"
  ok W37-empty-parent-gone no "$([ -d "$PARENTS/shared/nested" ] && echo yes || echo no)"
  ok W37-stop-at-sibling yes "$([ -d "$PARENTS/shared/remaining" ] && echo yes || echo no)"
fi

CASE=W38; if want "$@"; then
  mkdir -p "$SANDBOX/empty-root/nested"
  C "$REPO" wt_remove_empty_parents "$SANDBOX/empty-root" "$SANDBOX/empty-root/nested/removed"
  C "$REPO" wt_remove_empty_parents "$SANDBOX/empty-root" "$SANDBOX/empty-root/top-level-removed"
  ok W38-root-preserved yes "$([ -d "$SANDBOX/empty-root" ] && echo yes || echo no)"
fi

CASE=W39; if want "$@"; then
  mkdir -p "$PARENTS-other/nested"
  C "$REPO" wt_remove_empty_parents "$PARENTS" "$PARENTS-other/nested/removed"
  ok W39-outside-preserved yes "$([ -d "$PARENTS-other/nested" ] && echo yes || echo no)"
fi

# --- sandbox guard ------------------------------------------------------------

# W12  Every case above ran with HOME redirected. Without that, wt_worktree_root
#      resolves into the user's live ~/dev/.worktrees and the suite creates real
#      worktrees there — a green run that damaged the machine.
CASE=W12; want "$@" && ok W12 "$REAL_BEFORE" "$(ls -A "$REAL_WT" 2>/dev/null | sort)"

printf '\n%d passed, %d failed%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
