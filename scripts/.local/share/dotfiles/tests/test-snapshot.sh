#!/usr/bin/env bash
# test-snapshot.sh — snapshot's contract: a manual run replaces the previous
# manual snapshot only after the new one exists; --daily prunes by age and
# stands down once Time Machine has a destination.
#
# Usage: bash test-snapshot.sh [S1 S4 ...]
#
# ISOLATION. `tmutil` is a stub on PATH that keeps its snapshot dates in a
# sandbox file and logs every call, and HOME is a temporary directory, so no
# real snapshot is taken or deleted. S7 asserts the real state directory was
# never written.

set -uo pipefail

SNAP="$(cd "$(dirname "$0")/../../../bin" && pwd)/snapshot"
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/snapshot-test.XXXXXX")
cd "$SANDBOX" || exit 1
REAL_STATE="$HOME/.local/state/snapshot"
real_state_before() { ls -la "$REAL_STATE" 2>/dev/null | shasum; }
REAL_STATE_BEFORE=$(real_state_before)
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

TODAY=$(date +%Y-%m-%d)
OLD=$(date -v-30d +%Y-%m-%d)-120000
RECENT=$(date -v-2d +%Y-%m-%d)-120000

mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/tmutil" <<'EOF'
#!/bin/sh
# Stub tmutil: snapshot dates live one per line in $STUB_STORE; new ones are
# today at 00:00:NN, NN counting up, so each is unique and inside any window.
printf '%s\n' "$*" >> "$STUB_LOG"
case "$1" in
  localsnapshot)
    [ "${STUB_TAKE_RC:-0}" -eq 0 ] || { echo "Failed to create local snapshot"; exit "$STUB_TAKE_RC"; }
    n=$(( $(wc -l < "$STUB_STORE") + 10 ))
    d="$STUB_TODAY-0000$n"
    echo "$d" >> "$STUB_STORE"
    echo "NOTE: local snapshots are considered purgeable and may be removed at any time by deleted(8)."
    echo "Created local snapshot with date: $d" ;;
  listlocalsnapshotdates)
    echo "Snapshot dates for volume group containing disk /:"
    cat "$STUB_STORE" ;;
  deletelocalsnapshots)
    grep -vx "$2" "$STUB_STORE" > "$STUB_STORE.new"; mv "$STUB_STORE.new" "$STUB_STORE"
    echo "Deleted local snapshot '$2'" ;;
  destinationinfo)
    if [ -n "${STUB_DEST:-}" ]; then echo "===================================================="; echo "Name          : Backup"
    else echo "tmutil: No destinations configured."; fi ;;
  *) echo "stub tmutil: unexpected: $*" >&2; exit 99 ;;
esac
EOF
chmod +x "$SANDBOX/bin/tmutil"
export PATH="$SANDBOX/bin:$PATH" STUB_TODAY="$TODAY"

# fresh: a new HOME, call log and snapshot store (seeded from the arguments).
fresh() {
    rm -rf "$SANDBOX/home"; mkdir -p "$SANDBOX/home"
    export HOME="$SANDBOX/home" STUB_LOG="$SANDBOX/calls" STUB_STORE="$SANDBOX/store"
    : > "$STUB_LOG"; : > "$STUB_STORE"
    for d in "$@"; do echo "$d" >> "$STUB_STORE"; done
    unset STUB_TAKE_RC STUB_DEST XDG_STATE_HOME SNAPSHOT_KEEP_DAYS
}
store() { tr '\n' ' ' < "$STUB_STORE" | sed 's/ $//'; }
manual_state() { cat "$HOME/.local/state/snapshot/manual" 2>/dev/null; }

CASE=S1; if want; then
    fresh "$OLD"
    out=$("$SNAP" 2>&1); rc=$?
    first=$(manual_state)
    ok "S1 exit 0" 0 "$rc"
    ok "S1 records the manual snapshot" "$TODAY-000011" "$first"
    ok "S1 reports it" "snapshot: $TODAY-000011" "$out"
    "$SNAP" >/dev/null 2>&1
    ok "S1 second run replaces the first, leaves others" "$OLD $TODAY-000012" "$(store)"
    ok "S1 state follows" "$TODAY-000012" "$(manual_state)"
    ok "S1 deletes only after taking" "localsnapshot deletelocalsnapshots" \
       "$(grep -E '^(localsnapshot|deletelocalsnapshots)' "$STUB_LOG" | tail -2 | cut -d' ' -f1 | tr '\n' ' ' | sed 's/ $//')"
fi

CASE=S2; if want; then
    fresh
    "$SNAP" >/dev/null 2>&1
    before=$(store)
    export STUB_TAKE_RC=1
    out=$("$SNAP" 2>&1); rc=$?
    ok "S2 failed take exits 1" 1 "$rc"
    ok "S2 says why" 1 "$(printf '%s' "$out" | grep -c 'tmutil localsnapshot failed')"
    ok "S2 keeps the previous snapshot" "$before" "$(store)"
    ok "S2 keeps the state" "$before" "$(manual_state)"
fi

CASE=S3; if want; then
    fresh "$OLD" "$RECENT"
    mkdir -p "$HOME/.local/state/snapshot"   # so a stray write would land
    out=$("$SNAP" --daily 2>&1); rc=$?
    ok "S3 exit 0" 0 "$rc"
    ok "S3 prunes older than 7 days, keeps recent and new" "$RECENT $TODAY-000012" "$(store)"
    ok "S3 reports the prune" 1 "$(printf '%s' "$out" | grep -c 'pruned 1 older than 7 days')"
    ok "S3 leaves the manual state alone" "" "$(manual_state)"
    fresh "$RECENT"; export SNAPSHOT_KEEP_DAYS=1
    "$SNAP" --daily >/dev/null 2>&1
    ok "S3 SNAPSHOT_KEEP_DAYS narrows the window" "$TODAY-000011" "$(store)"
fi

CASE=S4; if want; then
    fresh "$OLD"; export STUB_DEST=1
    out=$("$SNAP" --daily 2>&1); rc=$?
    ok "S4 exit 0" 0 "$rc"
    ok "S4 takes and deletes nothing" 0 "$(grep -cE '^(localsnapshot|deletelocalsnapshots)' "$STUB_LOG")"
    ok "S4 says Time Machine has it" 1 "$(printf '%s' "$out" | grep -c 'Time Machine has a destination')"
    "$SNAP" >/dev/null 2>&1
    ok "S4 manual still works with a destination" 1 "$(grep -c '^localsnapshot' "$STUB_LOG")"
fi

CASE=S5; if want; then
    fresh
    "$SNAP" --bogus >/dev/null 2>&1; ok "S5 unknown flag exits 2" 2 $?
    "$SNAP" --daily --list >/dev/null 2>&1; ok "S5 two flags exit 2" 2 $?
    ok "S5 bad arguments touch nothing" "" "$(cat "$STUB_LOG")"
fi

CASE=S6; if want; then
    fresh "$OLD" "$RECENT"
    ok "S6 --list prints dates only" "$OLD $RECENT" "$("$SNAP" --list | tr '\n' ' ' | sed 's/ $//')"
fi

CASE=S7; if want; then
    ok "S7 real state directory untouched" "$REAL_STATE_BEFORE" "$(real_state_before)"
fi

echo "snapshot: $PASS passed, $FAIL failed${FAILED:+ —$FAILED}"
[ "$FAIL" -eq 0 ]
