#!/usr/bin/env bash
# test-obq.sh: scripts/obq's contract. One query runs here and on the other
# machine, the answers come back in one object keyed by machine, a machine
# that cannot be reached is a warning, and an engine failure is an error.
#
# Usage: bash test-obq.sh [O1 O4 ...]     (run it from a scratch directory)
#
# ISOLATION. `obelisk` and `ssh` are stubs on a PATH that leaves out every
# directory holding the real engine, and HOME is a temporary directory holding
# the machine marker and a copy of the tree's twin manifest. The ssh stub runs
# the remote command under zsh, the login shell of both machines, with its own
# HOME, TMPDIR and engine stub, so "the other machine" is a sandbox directory.
# O13 asserts the stubs are what the wrapper reached and that nothing is left
# behind.

set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd -P)
OBQ=$HERE/../scripts/obq
ROOT=$(cd "$HERE/../../../../.." && pwd -P)
MANIFEST=$ROOT/twin/.config/twin/twin.toml
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/obq-test.XXXXXX")
SANDBOX=$(cd "$SANDBOX" && pwd -P)   # one spelling, so paths the stubs print compare equal
cleanup() {
    [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }
    case "$SANDBOX" in */obq-test.*) rm -rf "$SANDBOX" ;; esac
}
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

JQ_DIR=$(dirname "$(command -v jq)")
mkdir -p "$SANDBOX/bin" "$SANDBOX/peerbin" "$SANDBOX/q"

# Engine stub for this machine: log the call, echo back what it was given.
cat > "$SANDBOX/bin/obelisk" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$HERE_LOG"
case "${STUB_HERE:-ok}" in
  error) printf '{"error":"here boom","stack":"Error: here boom\\n    at x"}\n'; exit 1 ;;
esac
if [ "$1" = --query ]; then printf '{"where":"here","script":%s}\n' "$(jq -Rs . < "$2")"
else printf '{"where":"here","argv":%s}\n' "$(printf '%s\n' "$@" | jq -R . | jq -cs .)"; fi
EOF

# Engine stub for the other machine: also records where it ran and from which
# file, so a case can check the script arrived whole and the file is gone.
cat > "$SANDBOX/peerbin/obelisk" <<'EOF'
#!/bin/sh
printf '%s\tcwd=%s\n' "$*" "$PWD" >> "$THERE_LOG"
case "${STUB_THERE:-ok}" in
  error) printf '{"error":"there boom","stack":"Error: there boom\\n    at x"}\n'; exit 1 ;;
  empty) exit 0 ;;
  warn)  echo "Warning: incomplete claude source inventory" >&2 ;;
esac
if [ "$1" = --query ]; then printf '{"where":"there","script":%s}\n' "$(jq -Rs . < "$2")"
else printf '{"where":"there","argv":%s}\n' "$(printf '%s\n' "$@" | jq -R . | jq -cs .)"; fi
EOF

# ssh stub: record the options and the alias, then be the other machine.
cat > "$SANDBOX/bin/ssh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$SSH_LOG"
alias=""
while [ $# -gt 0 ]; do
  case "$1" in -o) shift 2 ;; --) shift; break ;; *) alias=$1; shift ;; esac
done
printf '%s\n' "$alias" >> "$SSH_ALIAS_LOG"
case "${STUB_SSH:-ok}" in
  unreachable) printf 'ssh: connect to host %s port 22: Operation timed out\r\n' "$alias" >&2; exit 255 ;;
  hang) echo $$ > "$SSH_PID"; exec sleep 30 ;;
esac
unset ZDOTDIR
cd "$PEER_HOME" && HOME="$PEER_HOME" TMPDIR="$PEER_TMP" PATH="$PEER_BIN:$PATH" exec /bin/zsh -f -c "$1"
EOF
chmod +x "$SANDBOX/bin/obelisk" "$SANDBOX/peerbin/obelisk" "$SANDBOX/bin/ssh"

export PATH="$SANDBOX/bin:$JQ_DIR:/usr/bin:/bin"
export HERE_LOG="$SANDBOX/here.log" THERE_LOG="$SANDBOX/there.log"
export SSH_LOG="$SANDBOX/ssh.log" SSH_ALIAS_LOG="$SANDBOX/ssh-alias.log" SSH_PID="$SANDBOX/ssh.pid"
export PEER_HOME="$SANDBOX/peerhome" PEER_TMP="$SANDBOX/peertmp" PEER_BIN="$SANDBOX/peerbin"

# fresh [machine]: a new HOME naming this machine (none when omitted) with the
# tree's manifest, empty logs, an empty other machine, default stub behaviour.
fresh() {
    rm -rf "$SANDBOX/home" "$PEER_HOME" "$PEER_TMP" "$SANDBOX/tmp"
    mkdir -p "$SANDBOX/home/.config/twin" "$PEER_HOME" "$PEER_TMP" "$SANDBOX/tmp"
    export HOME="$SANDBOX/home" TMPDIR="$SANDBOX/tmp"
    cp "$MANIFEST" "$HOME/.config/twin/twin.toml"
    [ -n "${1:-}" ] && echo "$1" > "$HOME/.config/machine"
    : > "$HERE_LOG"; : > "$THERE_LOG"; : > "$SSH_LOG"; : > "$SSH_ALIAS_LOG"; rm -f "$SSH_PID"
    unset STUB_HERE STUB_THERE STUB_SSH OBQ_TIMEOUT OBQ_CONNECT_TIMEOUT
}
# run <args…>: call the wrapper from the query directory; sets out, err, rc.
run() { out=$(cd "$SANDBOX/q" && "$OBQ" "$@" 2>"$SANDBOX/err"); rc=$?; err=$(cat "$SANDBOX/err"); }
j() { printf '%s' "$out" | jq -r "$1" 2>&1; }

SCRIPT_TEXT='return sql(`SELECT 1`); // it'\''s "quoted" $HOME `x` \n'
printf '%s\n' "$SCRIPT_TEXT" > "$SANDBOX/q/obq-test.mjs"
SCRIPT_BYTES=$(cat "$SANDBOX/q/obq-test.mjs")

CASE=O1; if want; then
    fresh mac
    run ./obq-test.mjs
    ok "O1 exit 0" 0 "$rc"
    ok "O1 one object, this machine first" "mac,mini" "$(j 'keys_unsorted | join(",")')"
    ok "O1 one line of output" 1 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
    ok "O1 the engine here gets the path as typed" "--query ./obq-test.mjs" "$(cat "$HERE_LOG")"
    ok "O1 the script reaches the other machine whole" "$SCRIPT_BYTES" "$(j '.mini.script' | sed '$d')"
    ok "O1 it runs there from a file under that machine's temp dir, in its home" 1 \
       "$(grep -c "^--query $PEER_TMP/obq\.[A-Za-z0-9]*	cwd=$PEER_HOME\$" "$THERE_LOG")"
    ok "O1 the file there is removed" "" "$(ls -A "$PEER_TMP")"
    ok "O1 ssh is non-interactive, bounded, and reaches the manifest's alias" "1 mini" \
       "$(grep -c -- '-o BatchMode=yes -o ConnectTimeout=4 ' "$SSH_LOG") $(cat "$SSH_ALIAS_LOG")"
    ok "O1 nothing on stderr" "" "$err"
fi

CASE=O2; if want; then
    fresh mac; export STUB_SSH=unreachable
    run ./obq-test.mjs
    ok "O2 an unreachable machine still exits 0" 0 "$rc"
    ok "O2 this machine's answer is intact" "here" "$(j '.mac.where')"
    ok "O2 the other is marked with ssh's reason" "ssh: connect to host mini port 22: Operation timed out" "$(j '.mini.not_reached')"
    ok "O2 one warning naming who answered" \
       "obq: warning: mini not reached (ssh: connect to host mini port 22: Operation timed out); answered by: mac" "$err"
fi

CASE=O3; if want; then
    fresh mac; export STUB_THERE=error
    run ./obq-test.mjs
    ok "O3 an engine failure on the other machine exits 1" 1 "$rc"
    ok "O3 its message, without the stack" '{"error":"there boom"}' "$(j '.mini | tojson')"
    ok "O3 this machine's answer is intact" "here" "$(j '.mac.where')"
    ok "O3 a failure is not a warning" 0 "$(printf '%s' "$err" | grep -c warning)"
fi

CASE=O4; if want; then
    fresh mac; export STUB_HERE=error
    run ./obq-test.mjs
    ok "O4 an engine failure here exits 1" 1 "$rc"
    ok "O4 its message" "here boom" "$(j '.mac.error')"
    ok "O4 the other machine's answer is intact" "there" "$(j '.mini.where')"
fi

CASE=O5; if want; then
    fresh mac; export STUB_THERE=empty
    run ./obq-test.mjs
    ok "O5 exit 0 with nothing printed is a failure" "1 exit 0 with no JSON on stdout" "$rc $(j '.mini.error')"
    fresh mac; export STUB_THERE=warn
    run ./obq-test.mjs
    ok "O5 an engine warning passes through, named" "0 obq: mini: Warning: incomplete claude source inventory" "$rc $err"
fi

CASE=O6; if want; then
    fresh mac; export STUB_SSH=hang OBQ_TIMEOUT=1
    start=$(date +%s); run ./obq-test.mjs; took=$(( $(date +%s) - start ))
    ok "O6 a machine that never answers is cut off" "0 no answer within 1s" "$rc $(j '.mini.not_reached')"
    ok "O6 within the cap, not the 30 s it would have taken" 1 "$( [ "$took" -lt 10 ] && echo 1 || echo 0 )"
    ok "O6 this machine's answer is intact" "here" "$(j '.mac.where')"
    ok "O6 stderr is the one warning" "obq: warning: mini not reached (no answer within 1s); answered by: mac" "$err"
    ok "O6 the ssh process is gone" 1 "$( kill -0 "$(cat "$SSH_PID")" 2>/dev/null && echo 0 || echo 1 )"
fi

CASE=O7; if want; then
    fresh mac
    run --on mini ./obq-test.mjs
    ok "O7 --on the other machine asks only it" "0 mini 0" "$rc $(j 'keys_unsorted | join(",")') $(wc -l < "$HERE_LOG" | tr -d ' ')"
    fresh mac
    run --on mac ./obq-test.mjs
    ok "O7 --on this machine never opens ssh" "0 mac 0" "$rc $(j 'keys_unsorted | join(",")') $(wc -l < "$SSH_LOG" | tr -d ' ')"
    run --on nope ./obq-test.mjs
    ok "O7 an unknown machine is a usage error naming the known ones" "2 obq: no machine named 'nope' (known: mac mini)" "$rc $err"
    ok "O7 and runs nothing" "" "$out"
fi

CASE=O8; if want; then
    fresh
    run ./obq-test.mjs
    ok "O8 no machine marker: here only, as local" "0 local 0" "$rc $(j 'keys_unsorted | join(",")') $(wc -l < "$SSH_LOG" | tr -d ' ')"
    fresh mac; rm "$HOME/.config/twin/twin.toml"
    run ./obq-test.mjs
    ok "O8 no manifest: here only, under its name" "0 mac 0" "$rc $(j 'keys_unsorted | join(",")') $(wc -l < "$SSH_LOG" | tr -d ' ')"
fi

CASE=O9; if want; then
    fresh mac
    run --search "it's two words" plain --nonce tok-1
    ok "O9 search: exit 0, both machines" "0 mac,mini" "$rc $(j 'keys_unsorted | join(",")')"
    ok "O9 the nonce stays on this machine" '["--search","it'\''s two words","plain","--nonce","tok-1"]' "$(j '.mac.argv | tojson')"
    ok "O9 the other machine gets the text, quoting intact, and no nonce" '["--search","it'\''s two words","plain"]' "$(j '.mini.argv | tojson')"
fi

CASE=O10; if want; then
    fresh mini
    run ./obq-test.mjs
    ok "O10 on the mini the other machine is the mac, by the manifest's alias" "0 mini,mac mac" \
       "$rc $(j 'keys_unsorted | join(",")') $(cat "$SSH_ALIAS_LOG")"
fi

CASE=O11; if want; then
    fresh mac; export STUB_SSH=unreachable
    run --on mini ./obq-test.mjs
    ok "O11 nobody answered: exit 1" 1 "$rc"
    ok "O11 and says so" 1 "$(printf '%s' "$err" | grep -c '^obq: no machine answered$')"
fi

CASE=O12; if want; then
    fresh mac
    run ./missing.mjs;  ok "O12 a missing script is a usage error" "2 obq: no such script: ./missing.mjs" "$rc $err"
    run;                ok "O12 no arguments is a usage error" 2 "$rc"
    run --search;       ok "O12 search without text is a usage error" 2 "$rc"
    run --search --nonce tok; ok "O12 a nonce alone is not text" 2 "$rc"
    ok "O12 none of them ran anything" "0 0" "$(wc -l < "$HERE_LOG" | tr -d ' ') $(wc -l < "$SSH_LOG" | tr -d ' ')"
fi

CASE=O13; if want; then
    fresh mac
    run ./obq-test.mjs
    ok "O13 the engine and ssh on the test PATH are the stubs" "$SANDBOX/bin/obelisk $SANDBOX/bin/ssh" "$(command -v obelisk) $(command -v ssh)"
    ok "O13 the run reached both stubs" "1 1" "$(wc -l < "$HERE_LOG" | tr -d ' ') $(wc -l < "$THERE_LOG" | tr -d ' ')"
    ok "O13 the wrapper leaves no temporary directory" "" "$(ls -A "$SANDBOX/tmp")"
fi

printf '\n%d passed, %d failed%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
