#!/usr/bin/env bash
# test-rex-agent.sh — rex-agent's mapping from Claude Code hooks to the state
# Rex keeps for a block, which drive, the agents board and every other reader
# take as where a session stands.
#
# Usage: bash test-rex-agent.sh [R1 R3 ...]
#
# What this pins: a turn that fails on an API error fires StopFailure, not
# Stop; a rejected login must read blocked with kind auth, and any other
# failure error, or the block keeps reading working with nothing running
# (R1, R2). The message is the session's last words, since StopFailure
# carries no message of its own (R1). Stop still reads done (R3); outside Rex
# it writes nothing (R4).
#
# ISOLATION. Each hook runs under script(1), whose pty stands in for the
# block's terminal and keeps the OSC 7501 sequence rex-agent writes to it.

set -uo pipefail

AGENT="$(cd "$(dirname "$0")/../../../../../rex/.local/bin" && pwd)/rex-agent"
PASS=0; FAIL=0; FAILED=""
SANDBOX=$(mktemp -d /tmp/rex-agent-test.XXXXXX)
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

# hook JSON [BLOCK]: the status rex-agent reports for one hook, as
# state[:kind=K] msg=TEXT, or nothing.
hook() {
    printf '%s' "$1" > "$SANDBOX/in.json"
    : > "$SANDBOX/tty"
    REX_BLOCK="${2-block:test}" script -q "$SANDBOX/tty" /bin/bash -c "'$AGENT' claude < '$SANDBOX/in.json'" < /dev/null >/dev/null 2>&1
    /usr/bin/python3 - "$SANDBOX/tty" <<'PY'
import base64, re, sys
raw = open(sys.argv[1], "rb").read().decode("utf-8", "replace")
m = re.search(r"\x1b\]7501;([^\x1b\x07]*)", raw)
if m:
    fields = dict(f.split("=", 1) for f in m.group(1).split(":") if "=" in f)
    out = fields["state"] + (":kind=" + fields["kind"] if "kind" in fields else "")
    if "msg" in fields:
        out += " msg=" + base64.b64decode(fields["msg"]).decode()
    print(out)
PY
}

CASE=R1; if want; then
    ok "R1 a rejected login reads blocked:auth with the session's last words" \
        "blocked:kind=auth msg=Login expired · Please run /login" \
        "$(hook '{"hook_event_name":"StopFailure","cwd":"/w/main","error":"authentication_failed","error_details":"401","last_assistant_message":"Login expired · Please run /login"}')"
fi

CASE=R2; if want; then
    ok "R2 another API failure reads error" "error msg=API Error: overloaded" \
        "$(hook '{"hook_event_name":"StopFailure","cwd":"/w/main","error":"rate_limit","last_assistant_message":"API Error: overloaded"}')"
fi

CASE=R3; if want; then
    ok "R3 a finished turn reads done" "done" "$(hook '{"hook_event_name":"Stop","cwd":"/w/main"}')"
fi

CASE=R4; if want; then
    ok "R4 outside Rex nothing is written" "" "$(hook '{"hook_event_name":"Stop","cwd":"/w/main"}' "")"
fi

echo "rex-agent: $PASS passed, $FAIL failed${FAILED:+ —$FAILED}"
[ "$FAIL" -eq 0 ]
