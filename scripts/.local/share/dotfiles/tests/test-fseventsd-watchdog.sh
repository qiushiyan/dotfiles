#!/usr/bin/env bash
# test-fseventsd-watchdog.sh — fseventsd-watchdog's contract: a footprint at
# or under the limit is only sampled; over it, fseventsd gets SIGTERM, then
# SIGKILL when it outlasts the wait, and the restart is logged with the new
# pid; within the hold window an over-limit read is logged as held and nothing
# is signalled; top's units are read as megabytes, and a value it cannot read
# signals nothing; samples are trimmed to 30 days; install writes a root copy
# identical to the script and a valid plist, and loads it; status reads both.
#
# Usage: bash test-fseventsd-watchdog.sh [W1 W4 ...]
#
# ISOLATION. FSEVENTSD_WATCHDOG_TEST_ROOT points every path the script writes
# into the sandbox and puts stub pgrep, top, kill, sleep and launchctl first
# on PATH. The stub kill answers only for the stub's own pid, so a signal
# can never reach a real process; W12 asserts the real fseventsd kept its
# pid and the real log directory is untouched. Run from anywhere: the suite
# cds into its sandbox first.

set -uo pipefail

# FSEVENTSD_WATCHDOG_BIN grades another build (a negative control).
BIN="${FSEVENTSD_WATCHDOG_BIN:-$(cd "$(dirname "$0")/../../../bin" && pwd)/fseventsd-watchdog}"
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/fsw-test.XXXXXX")
SANDBOX=$(cd "$SANDBOX" && pwd -P)
cd "$SANDBOX" || exit 1
cleanup() {
    [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }
    case "$SANDBOX" in */fsw-test.*) rm -rf "$SANDBOX" ;; esac
}
trap cleanup EXIT

REAL_PID=$(pgrep -x fseventsd | head -1)
REAL_LOGS=/Library/Logs/fseventsd-watchdog
real_logs_state() { [ -d "$REAL_LOGS" ] && ls -lT "$REAL_LOGS" 2>/dev/null; true; }
REAL_LOGS_BEFORE=$(real_logs_state)

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
has() {  # has <name> <needle> <haystack>
    case "$3" in *"$2"*) PASS=$((PASS+1)) ;;
    *) FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    missing: %s\n    in:      %s\n' "$1" "$2" "$3" ;; esac
}
want() { [ $# -eq 0 ] || [[ " $* " == *" $CASE "* ]]; }

# The stubs read and write $STUB_STATE: pid (the running fseventsd, empty for
# none), mem (top's MEM value), mode (what a signal does: term exits on TERM,
# ignore exits only on KILL, stuck survives both), and calls (every call).
write_stubs() {
    local b="$1/bin"; mkdir -p "$b"
    cat > "$b/pgrep" <<'EOF'
#!/bin/bash
echo "pgrep $*" >> "$STUB_STATE/calls"
[ "$*" = "-x fseventsd" ] || exit 1
p=$(cat "$STUB_STATE/pid" 2>/dev/null); [ -n "$p" ] || exit 1; echo "$p"
EOF
    cat > "$b/top" <<'EOF'
#!/bin/bash
echo "top $*" >> "$STUB_STATE/calls"
printf 'MEM   \n%s  \n' "$(cat "$STUB_STATE/mem")"
EOF
    cat > "$b/kill" <<'EOF'
#!/bin/bash
echo "kill $*" >> "$STUB_STATE/calls"
cur=$(cat "$STUB_STATE/pid" 2>/dev/null)
[ -n "$cur" ] && [ "$2" = "$cur" ] || exit 1
mode=$(cat "$STUB_STATE/mode")
respawn() { echo $((cur + 1000)) > "$STUB_STATE/pid"; }
case "$1" in
    -0) exit 0 ;;
    -TERM) [ "$mode" = term ] && respawn ;;
    -KILL) [ "$mode" != stuck ] && respawn ;;
esac
exit 0
EOF
    printf '#!/bin/bash\necho "sleep $*" >> "$STUB_STATE/calls"\n' > "$b/sleep"
    printf '#!/bin/bash\necho "launchctl $*" >> "$STUB_STATE/calls"\n' > "$b/launchctl"
    chmod +x "$b"/*
}

fresh() {  # fresh <pid> <mem> <mode>: a new sandbox root and stub state
    ROOT="$SANDBOX/$CASE/root"; export STUB_STATE="$SANDBOX/$CASE/state"
    rm -rf "$SANDBOX/$CASE"; mkdir -p "$ROOT" "$STUB_STATE"
    write_stubs "$ROOT"
    printf '%s' "$1" > "$STUB_STATE/pid"; printf '%s' "$2" > "$STUB_STATE/mem"; printf '%s' "$3" > "$STUB_STATE/mode"
    : > "$STUB_STATE/calls"
    LOGS="$ROOT/Library/Logs/fseventsd-watchdog"
}
run() { FSEVENTSD_WATCHDOG_TEST_ROOT="$ROOT" zsh "$BIN" "$@"; }
kills() { grep '^kill -[A-Z]' "$STUB_STATE/calls" | tr '\n' ';'; }
events() { cat "$LOGS/events.log" 2>/dev/null; }
samples_mb() { cut -f3 "$LOGS/samples.tsv" 2>/dev/null | tr '\n' ' '; }

CASE=W1; if want "$@"; then
    fresh 100 48M term; run check; rc=$?
    ok W1-exit 0 "$rc"
    ok W1-no-signal "" "$(kills)"
    ok W1-sample "48 " "$(samples_mb)"
    ok W1-no-event "" "$(events)"
fi

CASE=W2; if want "$@"; then
    fresh 100 2.5G term; run check; rc=$?
    ok W2-exit 0 "$rc"
    ok W2-term-only "kill -TERM 100;" "$(kills)"
    has W2-event "restarted: pid 100 at 2.5 GB exited on SIGTERM in 0 s; new pid 1100" "$(events)"
    [ -s "$LOGS/last-restart" ]; ok W2-last-restart 0 $?
fi

CASE=W3; if want "$@"; then
    fresh 100 37G ignore; run check; rc=$?
    ok W3-exit 0 "$rc"
    ok W3-term-then-kill "kill -TERM 100;kill -KILL 100;" "$(kills)"
    ok W3-waited-30 30 "$(grep -c '^sleep 1' "$STUB_STATE/calls" | awk '{print ($1 >= 30 && $1 <= 32) ? 30 : $1}')"
    has W3-event "pid 100 at 37.0 GB ignored SIGTERM for 30 s, killed; new pid 1100" "$(events)"
fi

CASE=W4; if want "$@"; then
    fresh 100 3G stuck; run check; rc=$?
    ok W4-exit 1 "$rc"
    has W4-event "pid 100 at 3.0 GB: still running after SIGKILL" "$(events)"
fi

CASE=W5; if want "$@"; then
    fresh 100 3G term; mkdir -p "$LOGS"; echo $(( $(date +%s) - 600 )) > "$LOGS/last-restart"
    run check; rc=$?
    ok W5-exit 0 "$rc"
    ok W5-no-signal "" "$(kills)"
    has W5-held "pid 100 at 3.0 GB, over 2.0 GB: restart held, the last was 10 min ago" "$(events)"
fi

CASE=W6; if want "$@"; then
    fresh 100 3G term; mkdir -p "$LOGS"; echo $(( $(date +%s) - 7200 )) > "$LOGS/last-restart"
    run check
    ok W6-restarts "kill -TERM 100;" "$(kills)"
fi

CASE=W7; if want "$@"; then
    got=""
    for v in 6512K 48M 37G 10G+ 1.5G 1024B; do
        fresh 100 "$v" term; run check; got="$got$(samples_mb)"
    done
    ok W7-units "6 48 37888 10240 1536 0 " "$got"
    fresh 100 garbage term; run check; rc=$?
    ok W7-unreadable-exit 0 "$rc"
    ok W7-unreadable-no-sample "" "$(samples_mb)"
    ok W7-unreadable-no-signal "" "$(kills)"
fi

CASE=W8; if want "$@"; then
    fresh "" 3G term; run check; rc=$?
    ok W8-exit 0 "$rc"
    ok W8-no-signal "" "$(kills)"
    ok W8-no-sample "" "$(samples_mb)"
fi

CASE=W9; if want "$@"; then
    fresh 100 2048M term; run check
    ok W9-at-limit "" "$(kills)"
    fresh 100 2049M term; run check
    ok W9-over-limit "kill -TERM 100;" "$(kills)"
fi

CASE=W10; if want "$@"; then
    fresh 100 48M term
    out=$(run install); rc=$?
    ok W10-exit 0 "$rc"
    cmp -s "$BIN" "$ROOT/usr/local/libexec/fseventsd-watchdog"; ok W10-copy-identical 0 $?
    P="$ROOT/Library/LaunchDaemons/com.qiushi.fseventsd-watchdog.plist"
    plutil -lint "$P" >/dev/null; ok W10-plist-valid 0 $?
    ok W10-plist-program /usr/local/libexec/fseventsd-watchdog "$(plutil -extract ProgramArguments.0 raw "$P")"
    ok W10-plist-interval 300 "$(plutil -extract StartInterval raw "$P")"
    has W10-bootstrap "launchctl bootstrap system $P" "$(cat "$STUB_STATE/calls")"
    has W10-status-current "installed and current" "$(run status)"
    echo "# edited" >> "$ROOT/usr/local/libexec/fseventsd-watchdog"
    has W10-status-differs "installed, but the copy differs" "$(run status)"
    mkdir -p "$LOGS"; echo keep > "$LOGS/events.log"
    run uninstall >/dev/null
    [ ! -e "$P" ] && [ ! -e "$ROOT/usr/local/libexec/fseventsd-watchdog" ]; ok W10-uninstall-removes 0 $?
    ok W10-uninstall-keeps-logs keep "$(cat "$LOGS/events.log")"
    has W10-status-not-installed "not installed" "$(run status)"
fi

CASE=W11; if want "$@"; then
    fresh 100 48M term; mkdir -p "$LOGS"
    awk 'BEGIN { for (i = 0; i < 9600; i++) printf "%d\t100\t40\n", 1700000000 + i }' > "$LOGS/samples.tsv"
    run check
    ok W11-trimmed 8640 "$(wc -l < "$LOGS/samples.tsv" | tr -d ' ')"
    ok W11-newest-kept 48 "$(tail -1 "$LOGS/samples.tsv" | cut -f3)"
fi

CASE=W13; if want "$@"; then
    fresh 100 48M term; mkdir -p "$LOGS"; now=$(date +%s)
    printf '%s\t100\t900\n%s\t100\t37888\n%s\t100\t50\n' $((now - 3*86400)) $((now - 2*86400)) $((now - 600)) > "$LOGS/samples.tsv"
    st=$(run status)
    has W13-peak-24h "24 h: 50 MB" "$st"
    has W13-peak-7d "7 d: 37.0 GB" "$st"
    has W13-now "pid 100, 48 MB" "$st"
fi

CASE=W14; if want "$@"; then
    FSEVENTSD_WATCHDOG_TEST_ROOT=relative zsh "$BIN" check 2>/dev/null; ok W14-relative-root-refused 2 $?
    FSEVENTSD_WATCHDOG_TEST_ROOT="$SANDBOX/missing" zsh "$BIN" check 2>/dev/null; ok W14-missing-root-refused 2 $?
fi

CASE=W12; if want "$@"; then
    ok W12-real-fseventsd-untouched "$REAL_PID" "$(pgrep -x fseventsd | head -1)"
    ok W12-real-logs-untouched "$REAL_LOGS_BEFORE" "$(real_logs_state)"
    bad=$(cat "$SANDBOX"/W*/state/calls 2>/dev/null | grep '^kill ' | awk '$3 !~ /^(1?100)$/' | head -3)
    ok W12-kills-only-stub-pids "" "$bad"
fi

printf '%d passed, %d failed%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
