#!/usr/bin/env bash
# test-worktree-core.sh — the pinned traps in worktree-core.sh's pure git logic.
#
# Usage: bash test-worktree-core.sh [W1 W5 ...]
#
# Scope is the tmux-FREE core (merged-ness, base resolution, base freshness, the
# gitignored-file seed). The popup's tmux glue is not exercised here; it needs a
# scratch server (see worktree.md).
#
# ISOLATION. wt_worktree_root builds paths under $HOME/dev/.worktrees, so a case
# that ran against the real HOME would create worktrees inside the user's own
# store — and `git fetch` against a real remote would reach the network. Every
# case runs with HOME pointed at a sandbox and a file:// "remote" built there;
# W12 asserts the real worktree store is untouched.

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
export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig"; : > "$GIT_CONFIG_GLOBAL"

# Run a core function inside a repo: C <repo> <fn> [args...]
C() { (cd "$1" && shift && source "$CORE" && "$@" 2>&1); }
# Same, reporting only the exit status — for the predicates.
Cq() { (cd "$1" && shift && source "$CORE" && "$@" >/dev/null 2>&1) && echo yes || echo no; }

# --- fixture: an "upstream" carrying every way work lands on a base ------------
#
# up/ is a BARE remote (a non-bare one refuses a push to its checked-out branch);
# repo/ pushes to it, so origin/HEAD resolves the way it does in real life. Four
# branches, one per merge style — the point of the fixture is that only ONE of
# them is an ancestor of the base.
UP="$SANDBOX/up.git"
git init -q --bare -b main "$UP"

REPO="$SANDBOX/repo"
git init -q -b main "$REPO"
git -C "$REPO" remote add origin "$UP"
git -C "$REPO" commit -q --allow-empty -m init
git -C "$REPO" push -q -u origin main
git -C "$REPO" remote set-head origin -a >/dev/null 2>&1

mkbranch() {  # two commits on a branch off main
    git -C "$REPO" checkout -q -b "$1" main
    for i in 1 2; do echo "$1-$i" >> "$REPO/$1.txt"; git -C "$REPO" add .; git -C "$REPO" commit -qm "$1 c$i"; done
    git -C "$REPO" checkout -q main
}
mkbranch squashed
mkbranch rebased
mkbranch trumerged
mkbranch open

git -C "$REPO" merge -q --squash squashed >/dev/null && git -C "$REPO" commit -qm "squashed (#1)"
# NB: no -q — cherry-pick has no such flag, and swallowing its output turned a
# fixture that never rebased anything into a green "not merged" verdict.
git -C "$REPO" cherry-pick $(git -C "$REPO" rev-list --reverse main..rebased) >/dev/null \
  || { echo "fixture: cherry-pick failed"; exit 1; }
git -C "$REPO" merge -q --no-ff trumerged -m "Merge trumerged"
git -C "$REPO" push -q origin main
git -C "$REPO" fetch -q origin

# --- merged-ness --------------------------------------------------------------

# W1  The graph-visible case. A real merge commit makes the branch an ancestor;
#     this is the only style the old `merge-base --is-ancestor` test could see.
CASE=W1; want "$@" && ok W1 yes "$(Cq "$REPO" wt_merged_into trumerged origin/main)"

# W2  THE BUG. GitHub's "Squash and merge" puts one brand-new commit on the base
#     that shares no history with the branch, so the ancestor test says "not
#     merged" about work that is demonstrably shipped — and ctrl-x then demands
#     a force-delete "drops their commits" for every squash-merged branch.
CASE=W2; want "$@" && ok W2 yes "$(Cq "$REPO" wt_merged_into squashed origin/main)"

# W3  "Rebase and merge" re-authors the commits: same patches, new SHAs, still
#     not ancestors. Caught per-commit rather than by the collapsed tree.
CASE=W3; want "$@" && ok W3 yes "$(Cq "$REPO" wt_merged_into rebased origin/main)"

# W4  The verdict that must stay NO. Everything above widens what counts as
#     merged, and the cost of widening too far is a silently deleted branch.
CASE=W4; want "$@" && ok W4 no "$(Cq "$REPO" wt_merged_into open origin/main)"

# W5  A branch with no net change against the merge base has no patch to match
#     on; an empty diff must not read as "already applied".
git -C "$REPO" checkout -q -b noop main
echo x > "$REPO/x"; git -C "$REPO" add .; git -C "$REPO" commit -qm add
git -C "$REPO" rm -q "$REPO/x"; git -C "$REPO" commit -qm remove
git -C "$REPO" checkout -q main
CASE=W5; want "$@" && ok W5 no "$(Cq "$REPO" wt_merged_into noop origin/main)"

# --- the memo -----------------------------------------------------------------
#
# Both cases poison the cache with a verdict we know is WRONG. That is the only
# way to prove the memo is really being read rather than silently recomputed —
# and, in W23, that a moved base doesn't reuse it.

CACHE="$REPO/.git/wt-merged-cache"
poison() { printf '%s %s %s\n' "$(git -C "$REPO" rev-parse "$1^{commit}")" \
                               "$(git -C "$REPO" rev-parse origin/main^{commit})" "$2" > "$CACHE"; }

# W22  A hit is served from the memo. Without it, the popup recomputes a
#      patch-id scan per worktree on every open to get an answer that only
#      changes when a ref moves.
poison open 1
CASE=W22; want "$@" && ok W22 yes "$(Cq "$REPO" wt_merged_into open origin/main)"

# W23  ...and the key is BOTH shas, so advancing the base retires the entry.
#      A memo keyed on the branch alone would keep answering "merged" after the
#      base moved — a cached verdict is what gets a branch force-deleted.
git -C "$REPO" commit -q --allow-empty -m "base moves on"
git -C "$REPO" push -q origin main && git -C "$REPO" fetch -q origin
CASE=W23; want "$@" && ok W23 no "$(Cq "$REPO" wt_merged_into open origin/main)"
rm -f "$CACHE"

# --- base resolution ----------------------------------------------------------

# W6  The base is the origin/HEAD symref, whatever the default branch is called.
CASE=W6; want "$@" && ok W6 origin/HEAD "$(C "$REPO" wt_default_base)"

# W7  ...but a HUMAN must never be shown "origin/HEAD" — "not merged into
#     origin/HEAD" reads as an internal error, not as a fact about main.
CASE=W7; want "$@" && ok W7 origin/main "$(C "$REPO" wt_base_display)"

# W8  The remote to refresh comes from the FULL ref name. Splitting the short
#     name on "/" would read a local branch `feat/x` as a remote called `feat`.
CASE=W8; want "$@" && ok W8 origin "$(C "$REPO" wt_base_remote)"

# W9  A repo with no remote has nothing to fetch — the base falls back to a
#     local branch, and wt_base_remote must stay silent rather than guess.
LOCAL="$SANDBOX/local"; git init -q -b main "$LOCAL"; git -C "$LOCAL" commit -q --allow-empty -m init
CASE=W9; want "$@" && ok W9 "" "$(C "$LOCAL" wt_base_remote)"

# --- base freshness -----------------------------------------------------------

# W10  A fetch that was killed mid-flight truncates FETCH_HEAD to empty with a
#      FRESH mtime. Testing mtime alone reads that as "just fetched" and skips
#      the refresh — the state where the answer is least trustworthy.
: > "$REPO/.git/FETCH_HEAD"
CASE=W10; want "$@" && ok W10 yes "$(Cq "$REPO" wt_base_is_stale)"

# W11  A real recent fetch is fresh, so the popup skips the network.
git -C "$REPO" fetch -q origin
CASE=W11; want "$@" && ok W11 no "$(Cq "$REPO" wt_base_is_stale)"

# --- fan-out ------------------------------------------------------------------

# W13  Output order must be INPUT order, not completion order. The rows carry
#      the markers the popup draws, so a list that reshuffles itself between
#      openings is a list you can't build muscle memory on.
#      Completion order here is c, b, a — the reverse of input order.
slow_echo() { case "$1" in a) sleep 0.3 ;; b) sleep 0.15 ;; esac; printf '%s%s\n' "$1" "$2"; }
CASE=W13; want "$@" && ok W13 "a1 b2 c3" "$(
    (source "$CORE"; printf 'a\t1\nb\t2\nc\t3\n' | wt_fanout slow_echo) | tr '\n' ' ' | sed 's/ $//')"

# W14  A bare `wait` inside the fan-out must not adopt the CALLER's background
#      job. The popup starts a base fetch in the background and awaits it later;
#      a fan-out that waited on it would block the list on the network — the one
#      thing backgrounding that fetch exists to prevent.
CASE=W14; want "$@" && ok W14 fast "$(
    ( source "$CORE" >/dev/null 2>&1
      sleep 5 & CALLER=$!
      start=$SECONDS
      printf 'x\t1\n' | wt_fanout printf >/dev/null
      [ $((SECONDS - start)) -lt 3 ] && echo fast || echo "blocked for $((SECONDS - start))s"
      kill "$CALLER" 2>/dev/null ) )"

# --- pre-deletion safety net ---------------------------------------------------

SNAP="$SANDBOX/dev/.worktrees/proj/snapme"
git -C "$REPO" worktree add -q "$SNAP" -b snapme main
printf 'tracked-edit\n' >> "$SNAP/squashed.txt"
printf 'brand new\n' > "$SNAP/untracked.txt"
printf 'ignored\n' > "$SNAP/ignore-me"
printf 'ignore-me\n' > "$SNAP/.gitignore"
SNAP_SHA=$(C "$SNAP" wt_snapshot_worktree "$SNAP" "test snapshot")

# W15  THE reason this isn't `git stash create`: a stash captures tracked
#      modifications only, and the dirt in an agent's worktree is mostly new
#      untracked files. Snapshotting those is the whole point.
CASE=W15; want "$@" && ok W15 "brand new" "$(git -C "$REPO" show "$SNAP_SHA:untracked.txt" 2>&1)"

# W16  Tracked edits ride along too.
CASE=W16; want "$@" && ok W16 yes "$(case "$(git -C "$REPO" show "$SNAP_SHA:squashed.txt" 2>&1)" in *tracked-edit*) echo yes;; *) echo no;; esac)"

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

# --- the slot guard -----------------------------------------------------------
#
# wt_slot_free is the last line before `git worktree add`, shared by create,
# gwt and the popup (brief classifies the same slot first, with more context).
# Free means absent or an empty real directory — git accepts that. Anything
# that may hold a session's work is refused; nothing here deletes.
SLOT="$SANDBOX/slot"; mkdir -p "$SLOT/empty" "$SLOT/full" "$SLOT/dark"
: > "$SLOT/full/f"; : > "$SLOT/file"; ln -s "$SLOT/full" "$SLOT/link"; chmod 000 "$SLOT/dark"
CASE=W30; want "$@" && ok W30 yes "$(Cq "$REPO" wt_slot_free "$SLOT/absent")"
CASE=W31; want "$@" && ok W31 yes "$(Cq "$REPO" wt_slot_free "$SLOT/empty")"
CASE=W32; want "$@" && ok W32 no  "$(Cq "$REPO" wt_slot_free "$SLOT/full")"
CASE=W33; want "$@" && ok W33 no  "$(Cq "$REPO" wt_slot_free "$SLOT/file")"
CASE=W34; want "$@" && ok W34 no  "$(Cq "$REPO" wt_slot_free "$SLOT/link")"
# W35  An unreadable directory lists as nothing; "nothing" must not mean free.
CASE=W35; want "$@" && ok W35 no  "$(Cq "$REPO" wt_slot_free "$SLOT/dark")"
chmod 755 "$SLOT/dark"

# --- sandbox guard ------------------------------------------------------------

# W12  Every case above ran with HOME redirected. Without that, wt_worktree_root
#      resolves into the user's live ~/dev/.worktrees and the suite creates real
#      worktrees there — a green run that damaged the machine.
CASE=W12; want "$@" && ok W12 "$REAL_BEFORE" "$(ls -A "$REAL_WT" 2>/dev/null | sort)"

printf '\n%d passed, %d failed%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
