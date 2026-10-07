#!/usr/bin/env bash
# test-tmux-exit-watch.sh — tmux-exit-watch's contract: every server in the
# socket directory is watched, and its exit is recorded as the kernel reports
# it (signal, clean exit, error exit), with the process table saved for any
# exit but a clean one; a stale socket is never asked again until a new
# server replaces it.
#
# Usage: bash test-tmux-exit-watch.sh [X1 X4 ...]
#
# ISOLATION. TMUX_TMPDIR points tmux at a socket directory inside the sandbox,
# and the watcher reaches tmux only through a wrapper that logs every call
# before running the real binary, so X6 can assert no call named a socket
# outside the sandbox. The state directory is in the sandbox; X6 also asserts
# the real one was never written. Run from anywhere: the suite cds into its
# sandbox first.

set -uo pipefail

# TMUX_EXIT_WATCH_BIN grades another build (a negative control: one that records nothing).
WATCH="${TMUX_EXIT_WATCH_BIN:-$(cd "$(dirname "$0")/../../../bin" && pwd)/tmux-exit-watch}"
REAL_TMUX=$(command -v tmux) || { echo "tmux not on PATH"; exit 2; }
PASS=0; FAIL=0; FAILED=""

# A short path: a unix socket path is limited to 104 bytes.
SANDBOX=$(mktemp -d /tmp/txw.XXXXXX)
cd "$SANDBOX" || exit 1
unset TMUX TMUX_PANE
export TMUX_TMPDIR="$SANDBOX"
SOCKS="$SANDBOX/tmux-$(id -u)"
STATE="$SANDBOX/state"
REAL_STATE="$HOME/.local/state/tmux-exit"
real_state() { ls -la "$REAL_STATE" 2>/dev/null | shasum; }
REAL_STATE_BEFORE=$(real_state)
WATCH_PID=""
cleanup() {
    [ -n "$WATCH_PID" ] && kill "$WATCH_PID" 2>/dev/null
    for s in "$SOCKS"/*; do [ -S "$s" ] && "$REAL_TMUX" -S "$s" kill-server 2>/dev/null; done
    pkill -f "$SANDBOX/fake-server" 2>/dev/null
    [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }
    case "$SANDBOX" in /tmp/txw.*) rm -rf "$SANDBOX" ;; esac
}
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
want() { [ $# -eq 0 ] || [[ " $* " == *" $CASE "* ]]; }
wait_for() {  # wait_for <seconds> <command...>
    local end=$((SECONDS + $1)); shift
    until "$@"; do [ $SECONDS -ge $end ] && return 1; sleep 0.1; done
}

# The wrapper logs, then runs the real tmux. A socket named fake-* belongs to
# fake-server, which tmux cannot talk to: the wrapper answers for it from the
# pid file fake-server wrote.
cat > "$SANDBOX/tmux" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$SANDBOX/tmux-calls.log"
if [ "\$1" = -S ] && [[ "\$2" == */fake-* ]]; then
    printf '%s\t3.7c\t%s\n' "\$(cat "\$2.pid")" "\$(date +%s)"; exit 0
fi
exec "$REAL_TMUX" "\$@"
EOF
chmod +x "$SANDBOX/tmux"

# fake-server <name> <code>: listens on a socket in the socket directory and
# exits with <code> once <name>.go exists — the error exit tmux's fatal makes.
cat > "$SANDBOX/fake-server" <<'EOF'
import os, socket, sys, time
path, code = sys.argv[1], int(sys.argv[2])
s = socket.socket(socket.AF_UNIX); s.bind(path); s.listen(1)
open(path + ".pid", "w").write(str(os.getpid()))
while not os.path.exists(path + ".go"):
    time.sleep(0.05)
sys.exit(code)
EOF

mkdir -p "$SOCKS" && chmod 700 "$SOCKS"
TMUX_EXIT_WATCH_TMUX="$SANDBOX/tmux" /usr/bin/python3 -I "$WATCH" \
    --socket-dir "$SOCKS" --state-dir "$STATE" --interval 0.2 > "$SANDBOX/watch.log" 2>&1 &
WATCH_PID=$!
disown "$WATCH_PID"

start_server() { "$REAL_TMUX" -L "$1" -f /dev/null new-session -d -s t "sleep 300"; }
server_pid() { "$REAL_TMUX" -L "$1" display-message -p '#{pid}'; }
watching() { grep -q "watching pid $1 " "$SANDBOX/watch.log"; }
records() { [ -f "$STATE/exits.jsonl" ] && wc -l < "$STATE/exits.jsonl" | tr -d ' ' || echo 0; }
has_records() { [ "$(records)" -ge "$1" ]; }
field() {  # field <line> <key>: one key of a record, JSON-encoded
    /usr/bin/python3 -I -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1]).get(sys.argv[2])))' "$1" "$2"
}
last_record() { tail -1 "$STATE/exits.jsonl"; }

CASE=X1; if want "$@"; then
    echo "X1 a SIGKILL is recorded as the signal, with the process table"
    start_server x1; pid=$(server_pid x1)
    wait_for 5 watching "$pid" || echo "  (watcher never registered $pid)"
    n=$(records); kill -9 "$pid"; wait_for 5 has_records $((n + 1))
    r=$(last_record)
    ok X1-kind '"signaled"' "$(field "$r" kind)"
    ok X1-signal '"SIGKILL"' "$(field "$r" signal)"
    ok X1-pid "$pid" "$(field "$r" pid)"
    ok X1-socket "\"$SOCKS/x1\"" "$(field "$r" socket)"
    ps_file=$(field "$r" processes | tr -d '"')
    case "$ps_file" in "$STATE"/*) ok X1-ps-in-sandbox yes yes ;; *) ok X1-ps-in-sandbox yes "$ps_file" ;; esac
    ok X1-ps-header yes "$(head -1 "$ps_file" 2>/dev/null | grep -q COMMAND && echo yes)"
fi

CASE=X2; if want "$@"; then
    echo "X2 kill-server is a clean exit, without a process table"
    start_server x2; pid=$(server_pid x2)
    wait_for 5 watching "$pid"
    n=$(records); "$REAL_TMUX" -L x2 kill-server; wait_for 5 has_records $((n + 1))
    r=$(last_record)
    ok X2-kind '"clean"' "$(field "$r" kind)"
    ok X2-code 0 "$(field "$r" exit_code)"
    ok X2-no-ps null "$(field "$r" processes)"
fi

CASE=X3; if want "$@"; then
    echo "X3 SIGTERM is tmux's graceful shutdown: a clean exit"
    start_server x3; pid=$(server_pid x3)
    wait_for 5 watching "$pid"
    n=$(records); kill -TERM "$pid"; wait_for 5 has_records $((n + 1))
    r=$(last_record)
    ok X3-kind '"clean"' "$(field "$r" kind)"
    ok X3-pid "$pid" "$(field "$r" pid)"
fi

CASE=X4; if want "$@"; then
    echo "X4 a stale socket is asked once, and a new server on its name is watched"
    start_server x4; pid=$(server_pid x4)
    wait_for 5 watching "$pid"
    n=$(records); kill -9 "$pid"; wait_for 5 has_records $((n + 1))
    asked() { grep -c -- "-S $SOCKS/x4 " "$SANDBOX/tmux-calls.log"; }
    before=$(asked); sleep 1.5
    ok X4-stale-not-asked "$before" "$(asked)"
    start_server x4; pid2=$(server_pid x4)
    ok X4-new-server-watched yes "$(wait_for 5 watching "$pid2" && echo yes)"
    n=$(records); kill -9 "$pid2"; wait_for 5 has_records $((n + 1))
    ok X4-second-record "$pid2" "$(field "$(last_record)" pid)"
fi

CASE=X5; if want "$@"; then
    echo "X5 a non-zero exit is an error exit, with the process table"
    /usr/bin/python3 -I "$SANDBOX/fake-server" "$SOCKS/fake-x5" 1 &
    wait_for 5 test -f "$SOCKS/fake-x5.pid"; pid=$(cat "$SOCKS/fake-x5.pid")
    wait_for 5 watching "$pid"
    n=$(records); touch "$SOCKS/fake-x5.go"; wait_for 5 has_records $((n + 1))
    r=$(last_record)
    ok X5-kind '"error-exit"' "$(field "$r" kind)"
    ok X5-code 1 "$(field "$r" exit_code)"
    ok X5-ps yes "$([ "$(field "$r" processes)" != null ] && echo yes)"
fi

CASE=X6; if want "$@"; then
    echo "X6 the watcher stayed inside the sandbox"
    outside=$(grep -- '-S ' "$SANDBOX/tmux-calls.log" 2>/dev/null | grep -vc -- "-S $SOCKS/")
    ok X6-sockets-in-sandbox 0 "$outside"
    ok X6-asked-something yes "$([ -s "$SANDBOX/tmux-calls.log" ] && echo yes)"
    ok X6-real-state-untouched "$REAL_STATE_BEFORE" "$(real_state)"
    ok X6-watcher-alive yes "$(kill -0 "$WATCH_PID" 2>/dev/null && echo yes)"
fi

echo
echo "pass $PASS, fail $FAIL${FAILED:+ —$FAILED}"
[ "$FAIL" -eq 0 ]
