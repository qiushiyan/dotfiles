#!/usr/bin/env bash
# test-grokbot-transcript.sh — grokbot-transcript's archive: the app keeps a
# bot's chat only as a rolling window, and --archive keeps every entry past it.
#
# Usage: bash test-grokbot-transcript.sh [G1 G4 ...]
#
# What this pins: the archive merges by seq and the window's copy of an entry
# wins, since an entry still in the window can change (G2); a gap between the
# archive and the window is reported, not papered over (G3); reads merge the
# archive with the window (G4). And two archivers never lose an entry: each
# replaces the archive with what it read, so one waits for the other's lock
# and reads the window only once it holds it (G5).
#
# ISOLATION. GROKBOT_DATA_DIR and GROKBOT_ARCHIVE_DIR point into a sandbox; G6
# asserts the real archive directory was not touched.

set -uo pipefail

TOOL="$(cd "$(dirname "$0")/../../../bin" && pwd)/grokbot-transcript"
PASS=0; FAIL=0; FAILED=""
SANDBOX=$(mktemp -d /tmp/grokbot-test.XXXXXX)
export GROKBOT_DATA_DIR="$SANDBOX/data" GROKBOT_ARCHIVE_DIR="$SANDBOX/archive"
REAL="$HOME/.local/state/grokbot"
real_before() { ls -la "$REAL" 2>/dev/null | shasum; }
REAL_BEFORE=$(real_before)
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

# blob KEY JSON: the app's store, one file per key, named by the key in base32.
blob() {
    local dir="$GROKBOT_DATA_DIR/sand-client-persistence" name
    mkdir -p "$dir"
    name=$(printf '%s' "$1" | /usr/bin/python3 -c 'import base64,sys; print(base64.b32encode(sys.stdin.buffer.read()).decode().rstrip("=").lower())')
    printf '%s' "$2" > "$dir/$name.blob"
}

# window SEQ:TEXT…: the bot's local window holds these entries.
window() {
    local entries="" e
    for e in "$@"; do
        entries+="${entries:+,}{\"seq\":${e%%:*},\"timestampMs\":$((1761100000000 + ${e%%:*} * 60000)),\"role\":\"assistant\",\"text\":\"${e#*:}\"}"
    done
    blob "u1.transcript.replicas.bot1" "{\"value\":{\"entries\":[$entries]}}"
}

blob "u1.roster.last-roster" '{"value":{"rows":[{"id":"bot1","name":"Session Driver"}]}}'
archived() { cut -d, -f1 "$GROKBOT_ARCHIVE_DIR/bot1.jsonl" 2>/dev/null | tr -dc '0-9\n' | tr '\n' ' ' | sed 's/ $//'; }
text_of() { /usr/bin/python3 -c 'import json,sys; [print(e["text"]) for e in map(json.loads, open(sys.argv[1])) if e["seq"] == int(sys.argv[2])]' "$GROKBOT_ARCHIVE_DIR/bot1.jsonl" "$1"; }

CASE=G1; if want; then
    window 1:a 2:b 3:c
    "$TOOL" "Session Driver" --archive >/dev/null 2>&1
    ok "G1 the window is archived" "1 2 3" "$(archived)"
fi

CASE=G2; if want; then
    window 3:c-edited 4:d 5:e
    "$TOOL" "Session Driver" --archive >/dev/null 2>&1
    ok "G2 merged by seq" "1 2 3 4 5" "$(archived)"
    ok "G2 the window's copy wins" "c-edited" "$(text_of 3)"
fi

CASE=G3; if want; then
    window 8:h 9:i
    err=$("$TOOL" "Session Driver" --archive 2>&1 >/dev/null)
    ok "G3 a gap is reported" "gap: seq 6–7" "$(printf '%s' "$err" | grep -o 'gap: seq [0-9]*–[0-9]*')"
fi

CASE=G4; if want; then
    window 9:i 10:j
    ok "G4 reads merge the archive and the window" "1 2 3 4 5 8 9 10" \
        "$("$TOOL" "Session Driver" --jsonl | /usr/bin/python3 -c 'import json,sys; print(" ".join(str(json.loads(l)["seq"]) for l in sys.stdin))')"
fi

CASE=G5; if want; then
    window 11:k
    mkdir -p "$GROKBOT_ARCHIVE_DIR"
    # Hold the archive's lock, start an archiver, move the window on, let go:
    # the archiver must read the window it finds once the lock is its own.
    /usr/bin/python3 -c '
import fcntl, sys, time
f = open(sys.argv[1], "w"); fcntl.flock(f, fcntl.LOCK_EX)
open(sys.argv[2], "w").close()
time.sleep(2)' "$GROKBOT_ARCHIVE_DIR/.bot1.lock" "$SANDBOX/locked" &
    holder=$!
    while [ ! -e "$SANDBOX/locked" ]; do sleep 0.05; done
    "$TOOL" "Session Driver" --archive >/dev/null 2>&1 &
    archiver=$!
    sleep 0.5
    window 11:k 12:l
    wait "$holder" "$archiver"
    ok "G5 an archiver waiting on the lock reads the window after it" "12" "$(archived | awk '{print $NF}')"
fi

CASE=G6; if want; then
    ok "G6 the real archive is untouched" "$REAL_BEFORE" "$(real_before)"
fi

echo "grokbot-transcript: $PASS passed, $FAIL failed${FAILED:+ —$FAILED}"
[ "$FAIL" -eq 0 ]
