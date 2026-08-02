#!/usr/bin/env bash
# handoff-path.test.sh — the pinned traps for baton path resolution.
#
# Each case exists because something specific can silently go wrong; the comment
# on each says what. Usage: bash handoff-path.test.sh [T1 T5 ...]
#
# ISOLATION. handoff-path.sh mkdir -p's into $HOME/dev/.handoffs, so a test that
# ran against the real HOME would scatter folders through the user's own baton
# store. Every case runs with HOME pointed at a sandbox and builds its repos
# there; T11 asserts the real store is untouched.

set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/handoff-path.sh"
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/handoff-path-test.XXXXXX")
REAL_HANDOFFS="$HOME/dev/.handoffs"
REAL_BEFORE=$(ls -A "$REAL_HANDOFFS" 2>/dev/null | sort)

# A second root OUTSIDE the sandboxed HOME, for the repo that has to miss both
# home-relative branches.
OUTSIDE=$(mktemp -d "${TMPDIR:-/tmp}/handoff-path-outside.XXXXXX")

cleanup() { rm -rf "${SANDBOX:-}" "${OUTSIDE:-}"; }
trap cleanup EXIT

# The script reads $HOME to place the store and to decide what counts as the dev
# root, so overriding it redirects both at once.
R() { (cd "$1" && HOME="$SANDBOX" bash "$SCRIPT" "${@:2}" 2>&1); }

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ $# -eq 0 ] && return 0; case " $* " in *" $CASE "*) return 0;; esac; return 1; }

# Echoes "yes" when <haystack> contains <needle>, else the haystack, so a failed
# assertion prints what actually came back.
has() { case "$1" in *"$2"*) echo yes;; *) echo "$1";; esac; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkrepo() { mkdir -p "$1" && git init -q "$1" && git -C "$1" commit -q --allow-empty -m init; }

D="$SANDBOX/dev"
mkrepo "$D/headroom"
mkrepo "$D/planlab/main"
git -C "$D/planlab/main" worktree add -q "$D/.worktrees/main/email-handling" -b email-handling
mkrepo "$SANDBOX/dotfiles"
mkrepo "$SANDBOX/elsewhere/vendor/thing"
mkrepo "$OUTSIDE/vendor/thing"
mkrepo "$D/sub"
mkrepo "$D/super"
git -C "$D/super" -c protocol.file.allow=always submodule add -q "$D/sub" vendor 2>/dev/null
git init -q --bare "$D/bare.git"
mkdir -p "$SANDBOX/plain"

# T1  A checkout directly under the dev root is named for itself.
CASE=T1; want "$@" && ok T1 "$SANDBOX/dev/.handoffs/headroom/x.md" "$(R "$D/headroom" x)"

# T2  A checkout nested in a project folder keeps both halves. Taking the
#     basename alone files every <project>/main repo under a shared main/.
CASE=T2; want "$@" && ok T2 "$SANDBOX/dev/.handoffs/planlab-main/x.md" "$(R "$D/planlab/main" x)"

# T3  A linked worktree reports its MAIN checkout. --show-toplevel is the branch
#     directory here, which would name the project after the branch.
CASE=T3; want "$@" && ok T3 "$SANDBOX/dev/.handoffs/planlab-main/x.md" "$(R "$D/.worktrees/main/email-handling" x)"

# T4  A submodule is named for its own checkout. Its --git-common-dir points at
#     the superproject's .git/modules, which yielded a hidden .git-modules/ store.
CASE=T4; want "$@" && ok T4 "$SANDBOX/dev/.handoffs/super-vendor/x.md" "$(R "$D/super/vendor" x)"

# T5  A repo at $HOME but outside the dev root still gets a plain name.
CASE=T5; want "$@" && ok T5 "$SANDBOX/dev/.handoffs/dotfiles/x.md" "$(R "$SANDBOX/dotfiles" x)"

# T6a  A deeply nested repo under $HOME flattens its whole path under the home.
CASE=T6a; want "$@" && ok T6a "$SANDBOX/dev/.handoffs/elsewhere-vendor-thing/x.md" "$(R "$SANDBOX/elsewhere/vendor/thing" x)"

# T6b  A repo outside $HOME entirely is bounded to its last two segments, rather
#      than flattening a whole absolute path into the folder name.
CASE=T6b; want "$@" && ok T6b "$SANDBOX/dev/.handoffs/vendor-thing/x.md" "$(R "$OUTSIDE/vendor/thing" x)"

# T7  A slug carrying the branch's own "/" nests, mirroring how the worktree
#     side lays out ~/dev/.worktrees/<project>/feat/login.
CASE=T7; want "$@" && ok T7 "$SANDBOX/dev/.handoffs/headroom/feat/login.md" "$(R "$D/headroom" feat/login)"

# T8  The parent directory is created, so the caller can write straight to the path.
CASE=T8
if want "$@"; then
    p=$(R "$D/headroom" made/up/deep); ok T8 "dir" "$([ -d "$(dirname "$p")" ] && echo dir || echo missing)"
fi

# T9  A bare repository has no checkout to name, and fails rather than naming
#     the project after whatever directory happens to contain it.
CASE=T9
if want "$@"; then
    out=$(R "$D/bare.git" x); rc=$?
    ok T9a "1" "$rc"
    ok T9b "yes" "$(has "$out" "bare repository")"
fi

# T10  Outside a repository, and a wrong argument count, both fail loudly.
CASE=T10
if want "$@"; then
    out=$(R "$SANDBOX/plain" x); ok T10a "1" "$?"
    ok T10b "yes" "$(has "$out" "not inside a git repository")"
    out=$(R "$D/headroom"); ok T10c "2" "$?"
    out=$(R "$D/headroom" a b); ok T10d "2" "$?"
fi

# T11  The user's real baton store is never touched — every case above ran with
#      HOME redirected, and a regression there would scatter folders into it.
CASE=T11; want "$@" && ok T11 "$REAL_BEFORE" "$(ls -A "$REAL_HANDOFFS" 2>/dev/null | sort)"

printf '\n%d passed, %d failed%s\n' "$PASS" "$FAIL" "${FAILED:+ —$FAILED}"
[ "$FAIL" -eq 0 ]
