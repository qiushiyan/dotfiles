#!/usr/bin/env bash
# test-git-warm.sh — git-warm's contract: a worktree whose untracked cache
# holds is left alone however many files its read lstats; a stale or missing
# cache is rewritten, and the line says rewrote only when the read after it
# shows the cache repaired; a worktree git cannot read, or one already locked,
# is never rewritten; -n rewrites nothing.
#
# Usage: bash test-git-warm.sh [W1 W4 ...]
#
# ISOLATION. git-warm finds its clones through `git config --global`, so a
# sandbox HOME holds a .gitconfig naming sandbox clones only; W8 asserts nothing
# else is reachable from it. The script writes only to stdout and to those
# clones' indexes. Run from anywhere: the suite cds into its sandbox first.

set -uo pipefail

# GIT_WARM_BIN grades another build (a negative control: the previous script).
WARM="${GIT_WARM_BIN:-$(cd "$(dirname "$0")/../../../bin" && pwd)/git-warm}"
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/git-warm-test.XXXXXX")
cd "$SANDBOX" || exit 1
cleanup() {
    [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }
    case "$SANDBOX" in */git-warm-test.*) rm -rf "$SANDBOX" ;; esac
}
trap cleanup EXIT

REAL_HOME=$HOME
export HOME="$SANDBOX/home" GIT_CONFIG_NOSYSTEM=1
unset XDG_CONFIG_HOME GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
mkdir -p "$HOME"
cat > "$HOME/.gitconfig" <<'EOF'
[user]
	name = test
	email = test@example.com
[init]
	defaultBranch = main
[core]
	untrackedCache = true
	fsmonitor = false
EOF

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
want() { [ $# -eq 0 ] || [[ " $* " == *" $CASE "* ]]; }

# 1,500 tracked files in 150 directories: past the 100 directories that make a
# read stale, and past the 1,000 lstats a read without fsmonitor always costs.
git init -q base
for d in $(seq 1 150); do
    mkdir "base/d$d"
    for f in 0 1 2 3 4 5 6 7 8 9; do : > "base/d$d/f$f"; done
done
git -C base add . && git -C base commit -qm base

fresh() {  # fresh <name>: a clone only git-warm's config names, its cache settled
    DIR="$SANDBOX/$1"
    cp -R base "$DIR"
    git config --global --replace-all maintenance.repo "$DIR"
    # The cache trusts a directory only once its mtime is safely in the past.
    sleep 1.1
    git -C "$DIR" status --porcelain >/dev/null
    git -C "$DIR" status --porcelain >/dev/null
}
read_trace() { GIT_OPTIONAL_LOCKS=0 GIT_TRACE2_PERF=1 git -C "$1" status --porcelain 2>&1 >/dev/null; }
opendir() { read_trace "$1" | sed -n 's/.*opendir:\([0-9]*\).*/\1/p' | head -1; }
lstats() { read_trace "$1" | sed -n 's/.*sum_lstat:\([0-9]*\).*/\1/p' | head -1; }
index_sum() { shasum "$1/.git/index" | cut -d' ' -f1; }
stale_it() { echo 'matches-nothing' >> "$1/.git/info/exclude"; }
drop_cache() { git -C "$1" update-index --no-untracked-cache 2>/dev/null; }

CASE=W1; if want "$@"; then
    # The fixture must be the case: a held cache and a read past 1,000 lstats.
    fresh w1
    ok "W1 fixture: the cache held" 0 "$(opendir "$DIR")"
    ok "W1 fixture: the read lstats every file" 1 "$([ "$(lstats "$DIR")" -gt 1000 ] && echo 1 || echo 0)"
    before=$(index_sum "$DIR")
    ok "W1 a held cache prints nothing" "" "$("$WARM")"
    ok "W1 a held cache is not rewritten" "$before" "$(index_sum "$DIR")"
fi

CASE=W2; if want "$@"; then
    fresh w2
    stale_it "$DIR"
    ok "W2 fixture: the read walked" 1 "$([ "$(opendir "$DIR")" -gt 100 ] && echo 1 || echo 0)"
    out=$("$WARM")
    ok "W2 a stale cache is rewritten" 1 "$(grep -c 'rewrote .*w2' <<<"$out")"
    ok "W2 the rewrite repaired it" 0 "$(opendir "$DIR")"
    ok "W2 the next run has nothing to do" "" "$("$WARM")"
fi

CASE=W3; if want "$@"; then
    # With core.untrackedCache on, a read without the lock builds a cache in
    # memory, so a cache missing from the index shows as a walk.
    fresh w3
    drop_cache "$DIR"
    ok "W3 fixture: the read walked" 1 "$([ "$(opendir "$DIR")" -gt 100 ] && echo 1 || echo 0)"
    out=$("$WARM")
    ok "W3 a missing cache is rewritten" 1 "$(grep -c 'rewrote .*w3' <<<"$out")"
    ok "W3 the cache is back" 0 "$(opendir "$DIR")"
fi

CASE=W4; if want "$@"; then
    # Git will not add a cache this clone's config refuses, so the status runs
    # and exits 0 and nothing is repaired, as when it loses the lock race.
    fresh w4
    git -C "$DIR" config core.untrackedCache false
    drop_cache "$DIR"
    out=$("$WARM")
    ok "W4 a rewrite that repaired nothing says so" 1 "$(grep -c 'failed to rewrite .*w4' <<<"$out")"
    ok "W4 it does not claim success" 0 "$(grep -c ' rewrote ' <<<"$out")"
fi

CASE=W5; if want "$@"; then
    fresh w5
    printf 'not an index' > "$DIR/.git/index"
    before=$(index_sum "$DIR")
    out=$("$WARM"); rc=$?
    ok "W5 an unreadable worktree is reported" 1 "$(grep -c 'could not read .*w5' <<<"$out")"
    ok "W5 it is not rewritten" 0 "$(grep -c 'rewrote' <<<"$out")"
    ok "W5 its index is left alone" "$before" "$(index_sum "$DIR")"
    ok "W5 the run still exits 0" 0 "$rc"
fi

CASE=W6; if want "$@"; then
    fresh w6
    stale_it "$DIR"
    : > "$DIR/.git/index.lock"
    before=$(index_sum "$DIR")
    ok "W6 a locked worktree prints nothing" "" "$("$WARM")"
    ok "W6 a locked worktree is not rewritten" "$before" "$(index_sum "$DIR")"
fi

CASE=W7; if want "$@"; then
    fresh w7
    stale_it "$DIR"
    before=$(index_sum "$DIR")
    out=$("$WARM" -n)
    ok "W7 -n names the worktree" 1 "$(grep -c 'would rewrite .*w7' <<<"$out")"
    ok "W7 -n rewrites nothing" "$before" "$(index_sum "$DIR")"
fi

CASE=W8; if want "$@"; then
    fresh w8
    ok "W8 HOME is the sandbox" 1 "$([ "$HOME" != "$REAL_HOME" ] && [[ "$HOME" == "$SANDBOX"/* ]] && echo 1 || echo 0)"
    ok "W8 the only clone in reach is the sandbox's" "$DIR" "$(git config --global --type=path --get-all maintenance.repo)"
fi

CASE=W9; if want "$@"; then
    # info/exclude is shared, so one change invalidates every linked worktree.
    fresh w9
    git -C "$DIR" worktree add -q "$SANDBOX/w9-linked" -b linked
    sleep 1.1
    git -C "$SANDBOX/w9-linked" status --porcelain >/dev/null
    git -C "$SANDBOX/w9-linked" status --porcelain >/dev/null
    stale_it "$DIR"
    out=$("$WARM")
    ok "W9 every linked worktree is rewritten" 2 "$(grep -c ' rewrote ' <<<"$out")"
fi

echo "$PASS passed, $FAIL failed${FAILED:+:$FAILED}"
[ "$FAIL" -eq 0 ]
