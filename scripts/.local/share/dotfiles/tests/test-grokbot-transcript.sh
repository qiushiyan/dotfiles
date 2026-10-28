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
# The text view: zsh's grokbot.zsh logs a command the app runs here, with its
# exit status even when zsh execs it, and nothing for any other shell or the
# shells the command starts (G7); the view puts each logged command in the
# turn whose request id it carries and leaves out other requests' (G8); a
# card shows every question with the bot's pick (G9); a drive batch whose
# webhook is named for the bot is spliced in, its intents and wake plumbing
# left out, and another bot's batch is never read (G10).
#
# ISOLATION. GROKBOT_DATA_DIR, GROKBOT_ARCHIVE_DIR and DRIVE_STATE_DIR point
# into a sandbox, and a stub `drive` heads PATH; G6 asserts the real archive
# directory was not touched.

set -uo pipefail

TOOL="$(cd "$(dirname "$0")/../../../bin" && pwd)/grokbot-transcript"
MODULE="$(cd "$(dirname "$0")/../../../../../zsh/.config/zsh" && pwd)/grokbot.zsh"
PASS=0; FAIL=0; FAILED=""
SANDBOX=$(mktemp -d /tmp/grokbot-test.XXXXXX)
export GROKBOT_DATA_DIR="$SANDBOX/data" GROKBOT_ARCHIVE_DIR="$SANDBOX/archive" DRIVE_STATE_DIR="$SANDBOX/drive"
# drive: logs each call and prints the events $SANDBOX/events-<batch>.json holds.
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/drive" <<'EOF'
#!/bin/sh
echo "$*" >> "$(dirname "$0")/../drive-calls"
cat "$(dirname "$0")/../events-$3.json" 2>/dev/null || echo '[]'
EOF
chmod +x "$SANDBOX/bin/drive"
export PATH="$SANDBOX/bin:$PATH"
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

# turn_window: a request rq1 (you, then the bot), a request rq2 with a card, then
# a later message, at seq 20–23, minutes apart from 10:00 on 2025-10-22 UTC.
turn_window() {
    blob "u1.transcript.replicas.bot1" '{"value":{"entries":[
 {"seq":20,"timestampMs":1761127200000,"kind":"message","role":"user","content":"check the disk","requestId":"rq1"},
 {"seq":21,"timestampMs":1761127260000,"kind":"send-message","message":{"type":"text","content":"disk is fine"},"requestId":"rq1"},
 {"seq":22,"timestampMs":1761127320000,"kind":"send-message","requestId":"rq2","widgetSkipped":true,"message":{"type":"widget","widget":{"prompt":"A1: two calls","options":[],"steps":[
   {"prompt":"Merge it?","options":[{"label":"Merge","style":"primary"},{"label":"Hold"}],"allowCustom":true},
   {"prompt":"Tell Glen?","options":[{"label":"Yes"},{"label":"No","style":"primary"}]}]}}},
 {"seq":23,"timestampMs":1761127500000,"kind":"send-message","message":{"type":"text","content":"later"},"requestId":"rq3"}]}}'
}

CASE=G7; if want; then
    mkdir -p "$SANDBOX/zdot"
    printf 'source %q\n' "$MODULE" > "$SANDBOX/zdot/.zshenv"
    log="$GROKBOT_ARCHIVE_DIR/host-commands.jsonl"
    rm -f "$log"
    ZDOTDIR="$SANDBOX/zdot" CURSOR_AGENT=1 CURSOR_REQUEST_ID=rq1 /bin/zsh -c 'ls /nonexistent-g7' 2>/dev/null
    ok "G7 the shell keeps the command's status" "1" "$?"
    ZDOTDIR="$SANDBOX/zdot" CURSOR_AGENT=1 CURSOR_REQUEST_ID=rq1 /bin/zsh -c 'zsh -c "true"; echo "a\"b"' >/dev/null
    ZDOTDIR="$SANDBOX/zdot" /bin/zsh -c 'true'
    ZDOTDIR="$SANDBOX/zdot" CURSOR_AGENT=1 CURSOR_REQUEST_ID=other /bin/zsh -c 'echo elsewhere' >/dev/null
    ok "G7 one start and one end per logged command, none for the nested or plain shell" \
        "start rq1 ls /nonexistent-g7|end 1|start rq1 zsh -c \"true\"; echo \"a\\\"b\"|end 0|start other echo elsewhere|end 0" \
        "$(/usr/bin/python3 -c '
import json, sys
out = []
for l in open(sys.argv[1]):
    r = json.loads(l)
    out.append(" ".join(["start", r["request_id"], r["cmd"]]) if r["t"] == "start" else "end %d" % r["status"])
print("|".join(out))' "$log")"
    ok "G7 the log is private" "600" "$(stat -f %Lp "$log")"
fi

CASE=G8; if want; then
    turn_window
    # The logged commands' times: G7's real ones lie years after this window,
    # so shift them to 10:00:30 on its day.
    /usr/bin/python3 -c '
import json, sys
p = sys.argv[1]; rows = [json.loads(l) for l in open(p)]
base = rows[0]["at_ms"]
for r in rows: r["at_ms"] = 1761127230000 + (r["at_ms"] - base)
open(p, "w").write("".join(json.dumps(r) + "\n" for r in rows))' "$GROKBOT_ARCHIVE_DIR/host-commands.jsonl"
    out=$("$TOOL" "Session Driver" --since seq:20 --tz UTC 2>/dev/null)
    ok "G8 the turn counts its commands" "── turn rq1 · you · first reply 1m00s · 1 message · spans 1m00s · 2 commands here, 1 failed" \
        "$(printf '%s\n' "$out" | grep '── turn rq1')"
    ok "G8 a command sits in its turn, before the reply" "10:00:30 ls /nonexistent-g7  (exit 1" \
        "$(printf '%s\n' "$out" | sed -n '3p' | sed 's/^  \$ //' | cut -c1-36)"
    ok "G8 another request's command is left out" "" "$(printf '%s\n' "$out" | grep elsewhere)"
fi

CASE=G9; if want; then
    turn_window
    ok "G9 every question, the bot's pick starred" "  1. Merge it? [★ Merge | Hold | own answer]|  2. Tell Glen? [Yes | ★ No]|  → skipped" \
        "$("$TOOL" "Session Driver" --since seq:22 --chat 2>/dev/null | sed -n '2,4p' | paste -sd'|' -)"
fi

CASE=G10; if want; then
    turn_window
    mkdir -p "$DRIVE_STATE_DIR/batches/b1" "$DRIVE_STATE_DIR/batches/b2"
    echo '{"name":"b1","webhook":"session-driver"}' > "$DRIVE_STATE_DIR/batches/b1/batch.json"
    echo '{"name":"b2","webhook":"itell"}' > "$DRIVE_STATE_DIR/batches/b2/batch.json"
    echo '[{"at":"2025-10-22T10:02:30Z","kind":"wake","session":"S1","outcome":"done","http":200},
           {"at":"2025-10-22T10:02:31Z","kind":"watch","session":"S1"},
           {"at":"2025-10-22T10:02:32Z","kind":"send-intent","session":"S1","text":"x"}]' > "$SANDBOX/events-b1.json"
    rm -f "$SANDBOX/drive-calls"
    out=$("$TOOL" "Session Driver" --since seq:20 --tz UTC 2>/dev/null)
    ok "G10 the bot's batch is spliced in by time" "  ⚙ 10:02:30 drive wake S1: done|[10-22 10:05] bot: later" \
        "$(printf '%s\n' "$out" | grep -A2 'drive wake' | grep -v '── turn' | paste -sd'|' -)"
    ok "G10 intents and wake plumbing are left out" "" "$(printf '%s\n' "$out" | grep -e 'drive watch' -e 'send-intent')"
    ok "G10 only the bot's own batch is read" "log --batch b1 --json" "$(cat "$SANDBOX/drive-calls")"
fi

CASE=G6; if want; then
    ok "G6 the real archive is untouched" "$REAL_BEFORE" "$(real_before)"
fi

echo "grokbot-transcript: $PASS passed, $FAIL failed${FAILED:+ —$FAILED}"
[ "$FAIL" -eq 0 ]
