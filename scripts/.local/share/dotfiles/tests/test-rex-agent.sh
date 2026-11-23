#!/usr/bin/env bash
# test-rex-agent.sh — rex-agent's mapping from Claude Code hooks to the state
# Rex keeps for a block, which drive, the app's Activity sidebar and every
# other reader take as where a session stands.
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
# A hook has no controlling tty. The report reaches the terminal of the
# process CLAUDE_PID names (R5), and nothing when that process has no
# terminal, even with one among the hook's ancestors (R6); without
# CLAUDE_PID, the nearest ancestor's terminal (R7). Rex discards a whole
# report whose text holds a control character or passes its limits, so text
# reaches it as typed but on one line and cut to fit: backslashes kept (R8),
# control characters made spaces (R9), the title under 192 bytes (R10), and a
# prompt that is just "-" still sent (R11).
#
# The lab reads a Claude pane's working directory from the OSC 7 report sent
# with each status: the checkout holding the agent's directory, whatever
# subdirectory it is in, percent-encoded (R12); a directory in no checkout as
# itself (R13); and nothing for a subagent's event, which may work in another
# checkout, while its status still goes (R14).
#
# ISOLATION. Each hook in R1-R4 and R8-R11 runs under script(1), whose pty
# stands in for the block's terminal and keeps the OSC 7501 sequence
# rex-agent writes to it. R5-R7 start every process tree detached (a new
# session, reparented to launchd), so the only terminal a hook can reach is a
# sandbox pty, never the one running this suite; CLAUDE_PID is unset for the
# rest.

set -uo pipefail
unset CLAUDE_PID

AGENT="$(cd "$(dirname "$0")/../../../../../rex/.local/bin" && pwd)/rex-agent"
PASS=0; FAIL=0; FAILED=""
SANDBOX=$(mktemp -d /tmp/rex-agent-test.XXXXXX)
cleanup() {
    local f; for f in "$SANDBOX"/*.pid; do [ -s "$f" ] && kill "$(cat "$f")" 2>/dev/null; done
    [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"
}
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

# hook JSON [BLOCK] [title|pwd]: the status rex-agent reports for one hook,
# as state[:kind=K] msg=TEXT, or nothing; with "title", its title and length;
# with "pwd", the directory its OSC 7 report names, decoded, or "none".
hook() {
    printf '%s' "$1" > "$SANDBOX/in.json"
    : > "$SANDBOX/tty"
    REX_BLOCK="${2-block:test}" script -q "$SANDBOX/tty" /bin/bash -c "'$AGENT' claude < '$SANDBOX/in.json'" < /dev/null >/dev/null 2>&1
    reported "$SANDBOX/tty" ${3:+"$3"}
}

# reported FILE [title|pwd]: the report recorded in FILE, as hook prints it,
# with "title" the title's text and its length in bytes, or with "pwd" the
# path of the OSC 7 report that comes before it.
reported() {
    /usr/bin/python3 - "$@" <<'PY'
import base64, re, sys, urllib.parse
raw = open(sys.argv[1], "rb").read().decode("utf-8", "replace")
if sys.argv[2:] == ["pwd"]:
    p = re.search(r"\x1b\]7;file://[^/\x1b]*(/[^\x1b\x07]*)\x1b\\\x1b\]7501;", raw)
    print(urllib.parse.unquote(p.group(1)) if p else "none")
    sys.exit()
m = re.search(r"\x1b\]7501;([^\x1b\x07]*)", raw)
if m:
    fields = dict(f.split("=", 1) for f in m.group(1).split(":") if "=" in f)
    if sys.argv[2:] == ["title"]:
        title = base64.b64decode(fields.get("title", "")) if "title" in fields else b""
        print(title.decode(), len(title))
        sys.exit()
    out = fields["state"] + (":kind=" + fields["kind"] if "kind" in fields else "")
    if "msg" in fields:
        out += " msg=" + base64.b64decode(fields["msg"]).decode()
    print(out)
PY
}

# detached CMD...: run CMD in a new session with no controlling tty,
# reparented to launchd, so no ancestor of it holds this suite's terminal.
detached() {
    /usr/bin/python3 -c 'import os, sys
os.setsid()
if os.fork(): os._exit(0)
os.execvp(sys.argv[1], sys.argv[1:])' "$@" < /dev/null > /dev/null 2>&1
}

# until_file FILE: wait up to 5s for FILE to exist.
until_file() { local i; for i in $(seq 50); do [ -e "$1" ] && return 0; sleep 0.1; done; return 1; }

# standin NAME [tty]: a long-running stand-in for Claude Code, on a sandbox
# pty of its own when "tty" is given (recorded in NAME.tty, flushed at each
# write), else with no terminal; prints its pid, which cleanup kills.
standin() {
    local name=$SANDBOX/$1
    if [ "${2:-}" = tty ]; then
        detached script -q -F "$name.tty" /bin/sh -c "echo \$\$ > '$name.pid'; exec sleep 60"
    else
        detached /bin/sh -c "echo \$\$ > '$name.pid'; exec sleep 60"
    fi
    until_file "$name.pid" && sleep 0.2
    cat "$name.pid"
}

# ttyless_hook JSON PTY [CLAUDE_PID]: a hook with no controlling tty, run by a
# shell on a sandbox pty (recorded in PTY), the way Claude Code runs one; then
# the report PTY recorded, if any.
ttyless_hook() {
    local done="$SANDBOX/hook.done.$RANDOM"
    printf '%s' "$1" > "$SANDBOX/in.json"
    detached script -q "$2" /bin/sh -c "
        ${3:+CLAUDE_PID=$3 export CLAUDE_PID;} REX_BLOCK=block:test export REX_BLOCK
        /usr/bin/python3 -c 'import os, sys; os.setsid(); os.execvp(sys.argv[1], sys.argv[1:])' \
            '$AGENT' claude < '$SANDBOX/in.json'
        touch '$done'"
    until_file "$done" && sleep 0.2
    reported "$2"
}

# hook_from_claude JSON PID: a detached hook whose CLAUDE_PID is PID.
hook_from_claude() {
    local done="$SANDBOX/hook.done.$RANDOM"
    printf '%s' "$1" > "$SANDBOX/in.json"
    detached /bin/sh -c "CLAUDE_PID=$2 REX_BLOCK=block:test '$AGENT' claude < '$SANDBOX/in.json'; touch '$done'"
    until_file "$done" && sleep 0.2
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

CASE=R5; if want; then
    pid=$(standin claude5 tty)
    hook_from_claude '{"hook_event_name":"PostToolUse","cwd":"/w/main","tool_name":"Bash"}' "$pid"
    ok "R5 a hook with no tty reports to the terminal CLAUDE_PID names" \
        "working msg=ran Bash" "$(reported "$SANDBOX/claude5.tty")"
fi

CASE=R6; if want; then
    pid=$(standin claude6)
    ok "R6 a Claude Code with no terminal gets no report, though an ancestor has one" \
        "" "$(ttyless_hook '{"hook_event_name":"Stop","cwd":"/w/main"}' "$SANDBOX/r6.tty" "$pid")"
fi

CASE=R7; if want; then
    ok "R7 without CLAUDE_PID the nearest ancestor's terminal gets it" \
        "done" "$(ttyless_hook '{"hook_event_name":"Stop","cwd":"/w/main"}' "$SANDBOX/r7.tty")"
fi

CASE=R8; if want; then
    ok "R8 backslashes reach Rex as typed" 'working msg=path C:\temp\new' \
        "$(hook '{"hook_event_name":"UserPromptSubmit","cwd":"/w/main","prompt":"path C:\\temp\\new"}')"
fi

CASE=R9; if want; then
    ok "R9 control characters become spaces" 'working msg=one two three four five six' \
        "$(hook '{"hook_event_name":"UserPromptSubmit","cwd":"/w/main","prompt":"one\rtwo\u001bthree\u0085four\u007ffive\tsix"}')"
fi

CASE=R10; if want; then
    long=$(printf 'é%.0s' $(seq 120))
    title=$(hook "{\"hook_event_name\":\"Stop\",\"cwd\":\"/w/$long\"}" block:test title)
    ok "R10 a long directory name is cut to 48 characters, under 192 bytes" \
        "$(printf 'é%.0s' $(seq 48)) 96" "$title"
fi

CASE=R11; if want; then
    ok "R11 a prompt that is just a dash is still sent" 'working msg=-' \
        "$(hook '{"hook_event_name":"UserPromptSubmit","cwd":"/w/main","prompt":"-"}')"
fi

CASE=R12; if want; then
    repo="$SANDBOX/a repo é"
    mkdir -p "$repo/.git" "$repo/packages/loopy/src"
    ok "R12 the checkout holding the agent's directory is reported, encoded" "$repo" \
        "$(hook "{\"hook_event_name\":\"PostToolUse\",\"cwd\":\"$repo/packages/loopy/src\",\"tool_name\":\"Bash\"}" block:test pwd)"
fi

CASE=R13; if want; then
    mkdir -p "$SANDBOX/loose/dir"
    ok "R13 a directory in no checkout is reported as itself" "$SANDBOX/loose/dir" \
        "$(hook "{\"hook_event_name\":\"Stop\",\"cwd\":\"$SANDBOX/loose/dir\"}" block:test pwd)"
fi

CASE=R14; if want; then
    in="{\"hook_event_name\":\"PostToolUse\",\"cwd\":\"$SANDBOX\",\"tool_name\":\"Bash\",\"agent_id\":\"a1\",\"agent_type\":\"Explore\"}"
    ok "R14 a subagent's event reports no directory, and its status still goes" "none|working msg=ran Bash" \
        "$(hook "$in" block:test pwd)|$(hook "$in")"
fi

echo "rex-agent: $PASS passed, $FAIL failed${FAILED:+ —$FAILED}"
[ "$FAIL" -eq 0 ]
