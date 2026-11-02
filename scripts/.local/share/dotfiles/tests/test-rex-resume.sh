#!/usr/bin/env bash
# test-rex-resume.sh — a pane Rex restored brings its program back, the capture
# tools read a long scrollback, each machine declares the others as hosts, and
# rexd starts once however many shells ask at the same moment.
#
# Usage: bash test-rex-resume.sh [R1 R5 ...]
#
# What this pins: Claude Code's hooks record the pane's own conversation, its
# account and flags, and a child `claude -p` takes nothing (R1); only a person's
# exit forgets it (R2); a shell in a pane whose server still runs resumes nothing
# and a crash clears the record (R3); a conversation running elsewhere gets no
# second copy (R4); after a real server restart each pane keeps its block id and
# its shell enters the resume on the right account, once (R5); a sidecar's
# command comes back the same way (R6); seed records what runs now (R7); rex-run
# and rex-export read past the 1 MiB one control reply carries (R8); hosts follow
# ~/.config/machine (R9); rexd starts once, also after a start that died (R10).
#
# ISOLATION. A scratch Rex server under a short temporary HOME, with REX_*
# stripped so no call reaches the live server. Claude Code is a stub that
# registers in the sandbox and names itself `claude <flags>` to ps. A hook runs
# inside a scratch pane, since rex-agent writes to the nearest tty. One thing
# escapes: a pane Rex restores starts through login(1), which resets HOME, so its
# first shell reads the real ~/.zshrc, with REX_SERVER naming the scratch server
# and no record for a scratch block. The test then replaces that shell with one
# under the sandbox, and R11 asserts the live server and the real records are
# untouched.

set -uo pipefail
unset REX_SERVER REX_SESSION REX_BLOCK REX_BIN_DIR XDG_STATE_HOME XDG_CONFIG_HOME NO_COLOR FORCE_COLOR SSH_CONNECTION
unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_CHILD_SESSION
export TERM=xterm-256color

BIN="$(cd "$(dirname "$0")/../../../../../rex/.local/bin" && pwd)"
TREE="$(cd "$BIN/../.." && pwd)"
ZSH_REX="$(cd "$TREE/../zsh/.config/zsh" && pwd)/rex.zsh"
REAL_HOME=$HOME
PASS=0; FAIL=0; FAILED=""

live_server() { HOME=$REAL_HOME "$BIN/rex" --autostart=false server status 2>/dev/null | grep -E '^(pid|instance):' | tr '\n' ' '; }
real_records() { ls "$REAL_HOME/.local/state/rex-lab/panes" 2>/dev/null | wc -l | tr -d ' '; }
LIVE_BEFORE=$(live_server)

SB=$(mktemp -d /tmp/rr.XXXXXX)
case "$SB" in /tmp/rr.?*) ;; *) echo "bad sandbox $SB"; exit 1;; esac
export HOME=$SB SHELL=/bin/zsh
export HEADROOM_PRIMARY_NAME=tester
export PATH="$SB/.local/bin:$PATH"
mkdir -p "$SB/.config/rex" "$SB/.local/bin" "$SB/w1" "$SB/w2" "$SB/w3" "$SB/w4"
for f in init.lua lua scripts; do ln -s "$TREE/.config/rex/$f" "$SB/.config/rex/$f"; done
for t in rex rex-agent rex-resume rex-run rex-export; do ln -s "$BIN/$t" "$SB/.local/bin/$t"; done
cat > "$SB/.zshenv" <<ZE
export PATH="$SB/.local/bin:\$PATH"
ZE
cat > "$SB/.zshrc" <<ZR
export HEADROOM_PRIMARY_NAME=tester
PROMPT='sandbox> '
source "$ZSH_REX"
ZR
cd "$SB" || exit 1

in_sandbox() { "$BIN/rex" --autostart=false server status 2>/dev/null | grep -q "^endpoint: .*${SB#/}"; }
stop_server() { in_sandbox && "$BIN/rex" --autostart=false server stop >/dev/null 2>&1; sleep 1; }
start_server() {
    ( "$BIN/rex" server run --log-format text >>"$SB/server.log" 2>&1 & )
    local i; for i in $(seq 40); do in_sandbox && return 0; sleep 0.25; done
    echo "the scratch server did not start"; exit 1
}
cleanup() {
    stop_server
    [ -n "${KEEP:-}" ] && { echo "kept $SB"; return; }
    case "$SB" in /tmp/rr.?*) command rm -rf "$SB";; esac
}
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")
rx() { "$BIN/rex" --autostart=false "$@" 2>/dev/null; }
until_true() {  # until_true SECONDS COMMAND...
    local end=$(( $(date +%s) + $1 )); shift
    until "$@"; do [ "$(date +%s)" -ge "$end" ] && return 1; sleep 0.25; done
}
record() { printf '%s/.local/state/rex-lab/panes/%s.json' "$SB" "${1//:/_}"; }

# Claude Code: registers <config>/sessions/<pid>.json as the real one does and
# names itself "claude <flags>" to ps.
cat > "$SB/.local/bin/claude-stub.pl" <<'STUB'
use strict; use File::Path qw(make_path);
my ($cfg, $sid, $cwd, @flags) = @ARGV;
$0 = join(" ", "claude", @flags);
make_path("$cfg/sessions");
open(my $f, ">", "$cfg/sessions/$$.tmp"); print $f qq({"pid":$$,"sessionId":"$sid","cwd":"$cwd","status":"idle"}); close $f;
rename("$cfg/sessions/$$.tmp", "$cfg/sessions/$$.json");
sleep 600 while 1;
STUB

# x-<account>: the launcher. tester is the primary, in ~/.claude.
cat > "$SB/.local/bin/x-account" <<'LAUNCH'
#!/bin/bash
acct=$(basename "$0"); acct=${acct#x-}
if [ "$acct" = tester ]; then cfg="$HOME/.claude"; else cfg="$HOME/.claude-accounts/$acct"; fi
sid=""; flags=()
while [ $# -gt 0 ]; do case "$1" in --resume|--session-id) sid=$2; shift 2;; *) flags+=("$1"); shift;; esac; done
echo "x-$acct ${flags[*]} --resume $sid in $PWD env ${PLANLAB_AGENT_NUDGES:-}" >> "$HOME/launches.log"
exec env -i /usr/bin/perl "$HOME/.local/bin/claude-stub.pl" "$cfg" "$sid" "$PWD" "${flags[@]}"
LAUNCH
chmod +x "$SB/.local/bin/x-account"
ln -s x-account "$SB/.local/bin/x-tester"
ln -s x-account "$SB/.local/bin/x-other@example.com"
mkdir -p "$SB/.claude/sessions" "$SB/.claude-accounts/other@example.com/sessions"
cat > "$SB/.local/bin/marker-cmd" <<'MARK'
#!/bin/sh
echo "ran $*" >> "$HOME/marker.log"; sleep 600
MARK
chmod +x "$SB/.local/bin/marker-cmd"

start_server
SID=$(rx new probe --json --shell none -c "$SB" -- /bin/sleep 3000 | jq -r .session_id)

# Open a pane running a Claude stub; prints its block id.
claude_pane() {  # CONFIG SID DIR FLAGS...
    local cfg=$1 sid=$2 dir=$3; shift 3
    rx run -s "$SID" --focus=false --keep-open --shell none --json -c "$dir" -- /usr/bin/env -i /usr/bin/perl "$SB/.local/bin/claude-stub.pl" "$cfg" "$sid" "$dir" "$@" | jq -r '.block_ids[0]'
}
# Fire a Claude Code hook for BLOCK from inside a throwaway scratch pane.
hook() {  # BLOCK EVENT SID [REASON] [ENV=VALUE]
    local block=$1 event=$2 sid=$3 reason=${4:-} assign=${5:-X_=1}
    local json; json=$(jq -nc --arg e "$event" --arg s "$sid" --arg r "$reason" --arg c "$SB/w1" '{hook_event_name: $e, session_id: $s, cwd: $c} + (if $r == "" then {} else {reason: $r} end)')
    local helper; helper=$(rx run -s "$SID" --focus=false --shell none --json -- /usr/bin/env "$assign" REX_BLOCK="$block" HOME="$SB" PATH="$PATH" /bin/sh -c "printf '%s' '$json' | $SB/.local/bin/rex-agent claude; sleep 0.2" | jq -r '.block_ids[0]')
    sleep 0.6
}
has_record() { [ -f "$(record "$1")" ]; }
registered() { grep -lq "$1" "$SB"/.claude/sessions/*.json "$SB"/.claude-accounts/*/sessions/*.json 2>/dev/null; }
drop() { rx block close -s "$SID" "$1" >/dev/null; }
line_in() { env REX_BLOCK="$1" "$BIN/rex-resume" line; }  # what a shell in that pane would run

CASE=R1
A=""; B=""
if true; then
    A=$(claude_pane "$SB/.claude-accounts/other@example.com" sid-a "$SB/w1" --effort high --dangerously-skip-permissions)
    B=$(claude_pane "$SB/.claude" sid-b "$SB/w2")
    sleep 0.5
    hook "$A" SessionStart sid-a "" PLANLAB_AGENT_NUDGES=off
    hook "$B" SessionStart sid-b
    until_true 8 has_record "$A"; until_true 8 has_record "$B"
    ok "R1 the pane's conversation is recorded" "claude sid-a $SB/w1 $SB/.claude-accounts/other@example.com PLANLAB_AGENT_NUDGES=off --effort,high" \
        "$(jq -r '[.kind, .sid, .dir, .config, .env, (.extra | join(","))] | join(" ")' "$(record "$A")")"
    hook "$A" SessionStart sid-child
    sleep 6
    ok "R1 a child claude -p takes nothing" "sid-a" "$(jq -r .sid "$(record "$A")")"
    # A session that started before the hook: its first prompt records it.
    rm -f "$(record "$B")"
    hook "$B" UserPromptSubmit sid-b
    until_true 8 has_record "$B"
    ok "R1 a prompt records a session the hook never saw" "sid-b" "$(jq -r .sid "$(record "$B")" 2>/dev/null)"
fi

CASE=R2; if want; then
    hook "$A" SessionEnd sid-child prompt_input_exit
    ok "R2 another conversation's exit forgets nothing" "sid-a" "$(jq -r .sid "$(record "$A")")"
    hook "$A" SessionEnd sid-a other
    ok "R2 a server stopping keeps the record" "sid-a" "$(jq -r .sid "$(record "$A")")"
    C=$(claude_pane "$SB/.claude" sid-c "$SB/w3"); sleep 0.5
    hook "$C" SessionStart sid-c; until_true 8 has_record "$C"
    hook "$C" SessionEnd sid-c prompt_input_exit
    ok "R2 a person's exit forgets" "no" "$(has_record "$C" && echo yes || echo no)"
    drop "$C"
fi

CASE=R3; if want; then
    D=$(claude_pane "$SB/.claude" sid-d "$SB/w3"); sleep 0.5
    hook "$D" SessionStart sid-d; until_true 8 has_record "$D"
    pkill -f "claude-stub.pl.*sid-d"; pgrep -f '^claude' >/dev/null
    for f in "$SB"/.claude/sessions/*.json; do grep -q sid-d "$f" && kill -9 "$(basename "$f" .json)" 2>/dev/null; done
    sleep 0.3
    ok "R3 the same server resumes nothing" "" "$(line_in "$D")"
    ok "R3 and the crash clears the record" "no" "$(has_record "$D" && echo yes || echo no)"
    drop "$D"
fi

CASE=R4; if want; then
    E=$(rx run -s "$SID" --focus=false --keep-open --shell none --json -- /bin/sleep 600 | jq -r '.block_ids[0]')
    jq -n --arg b "$E" '{instance: "gone", kind: "claude", sid: "sid-a", dir: "/", config: "x", env: "", extra: []}' > "$(record "$E")"
    ok "R4 a conversation running elsewhere gets no second copy" "" "$(line_in "$E")"
    ok "R4 and the record stays" "yes" "$(has_record "$E" && echo yes || echo no)"
    rm -f "$(record "$E")"; drop "$E"
fi

CASE=R7; if want; then
    F=$(claude_pane "$SB/.claude" sid-f "$SB/w4" --model fable); sleep 0.5
    rm -f "$(record "$A")" "$(record "$B")"
    "$BIN/rex-resume" seed > "$SB/seed.out" 2>&1
    ok "R7 seed records every Claude Code running" "rex-resume: recorded 3 running Claude Code" "$(cat "$SB/seed.out")"
    ok "R7 with its conversation and flags" "sid-f $SB/.claude --model,fable" \
        "$(jq -r '[.sid, .config, (.extra | join(","))] | join(" ")' "$(record "$F")")"
    jq '.env = "PLANLAB_AGENT_NUDGES=off"' "$(record "$A")" > "$SB/a.json" && mv "$SB/a.json" "$(record "$A")"
fi

CASE=R5; if want; then
    # A sidecar's record, written from its pane as rex-steps does.
    G=$(rx run -s "$SID" --focus=false --keep-open --shell none --json -c "$SB/w4" -- /usr/bin/env HOME="$SB" PATH="$PATH" /bin/sh -c 'REX_BLOCK=$REX_BLOCK rex-resume note-command marker-cmd one two; sleep 600' | jq -r '.block_ids[0]')
    until_true 8 has_record "$G"
    # Stopped in place, as a shutdown does. (Unstub every registry: the stubs die with the server.)
    stop_server
    ( for f in "$SB"/.claude/sessions/*.json "$SB"/.claude-accounts/*/sessions/*.json; do
        pid=$(basename "$f" .json); kill -9 "$pid" 2>/dev/null; rm -f "$f"; done )
    start_server; sleep 2
    ok "R5 the session comes back under its id" "$SID" "$(rx ls --json | jq -r --arg s "$SID" '.sessions[] | select(.session_id == $s) | .session_id')"
    ok "R5 each pane keeps its block id" "yes yes yes" \
        "$(for b in "$A" "$B" "$G"; do rx block ls -s "$SID" --json | jq -e --arg b "$b" '.blocks[] | select(.block_id == $b)' >/dev/null && echo yes || echo no; done | tr '\n' ' ' | sed 's/ $//')"
    # The restored shell went through login(1), under the real HOME: replace it with
    # one under the sandbox, where the record is. This is the shell's own path from here.
    sandbox_shell() {
        rx send -s "$SID" -b "$1" "unset XDG_STATE_HOME XDG_CONFIG_HOME; HOME=$SB ZDOTDIR=$SB exec /bin/zsh -i"
        rx send-key -s "$SID" -b "$1" enter
    }
    sandbox_shell "$A"; sandbox_shell "$B"; sandbox_shell "$G"
    launched() { [ "$(grep -c "$1" "$SB/launches.log" 2>/dev/null)" = 1 ]; }
    until_true 15 launched sid-a; until_true 15 launched sid-b
    ok "R5 a conversation resumes on its account, flags and folder" "x-other@example.com --effort high --resume sid-a in $SB/w1 env off" \
        "$(grep sid-a "$SB/launches.log")"
    ok "R5 the primary's resumes on its launcher" "x-tester  --resume sid-b in $SB/w2 env " "$(grep sid-b "$SB/launches.log")"
    until_true 5 registered sid-a
    ok "R5 Claude Code runs again" "yes" "$(registered sid-a && echo yes || echo no)"
    ok "R5 the record is spent" "no" "$(has_record "$A" && echo yes || echo no)"
    # Its Claude exits and a new shell starts in the pane: no second resume.
    ok "R5 a later shell resumes nothing" "" "$(line_in "$B")"
    CASE=R6; if want; then
        marked() { grep -q 'ran one two' "$SB/marker.log" 2>/dev/null; }
        until_true 10 marked
        ok "R6 a sidecar's command comes back in its pane" "ran one two" "$(cat "$SB/marker.log" 2>/dev/null)"
        ok "R6 execed, so no shell waits behind it" "no" "$(rx block call -s "$SID" -b "$G" process | jq -r '[.child.name, .foreground.name] | join(" ")' | grep -q zsh && echo yes || echo no)"
    fi
fi

CASE=R8; if want; then
    P=$(rx run -s "$SID" --focus=false --keep-open --shell none --json -- /usr/bin/python3 -c 'for i in range(40000): print("line %06d https://example.com/x/%d abcdefghijklmnopqrstuvwxyz0123456789" % (i, i))' | jq -r '.block_ids[0]')
    sleep 3
    env REX_SESSION="$SID" REX_BLOCK="$P" "$BIN/rex-run" -l big -n 1 -- /bin/sh -c '/usr/bin/python3 -c "for i in range(40000): print(\"big %06d abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz\" % i)"; exit 4' > "$SB/run.out" 2>&1; code=$?
    ok "R8 rex-run hands back status and output past 1 MiB" "4 big 039999" "$code $(tail -1 "$SB/run.out" | cut -c1-10)"
    ok "R8 rex-run tail too" "big 039999" "$(env REX_SESSION="$SID" REX_BLOCK="$P" "$BIN/rex-run" tail big -n 1 | cut -c1-10)"
    env XDG_STATE_HOME="$SB/.local/state" "$BIN/rex-export" "$SID" "$P" > "$SB/export.out" 2> "$SB/export.err"
    page=$(cat "$SB/export.out")
    ok "R8 rex-export writes the whole coloured page" "yes yes" "$(grep -q 'line 039999' "$page" 2>/dev/null && echo yes || echo no) $(grep -q 'vt-palette\|<span\|<div' "$page" 2>/dev/null && echo yes || echo no)"
    drop "$P"
fi

CASE=R9; if want; then
    echo mini2 > "$SB/.config/machine"
    rx config reload >/dev/null
    ok "R9 mini2 declares the others" "mac qiushi-mac.tailf7adf1.ts.net|mini qiushi-mini-rex.tailf7adf1.ts.net|" \
        "$(rx hosts list | awk 'NR>1 {print $1, $2}' | sort | tr '\n' '|')"
    ok "R9 the config loads clean" "0" "$(rx config check "$SB/.config/rex/init.lua" 2>&1 | grep -c '^warning\|^error')"
    rm -f "$SB/.config/machine"
fi

CASE=R10; if want; then
    ln -sf "$BIN/rexd" "$SB/.local/bin/rexd"
    "$BIN/rexd" stop >/dev/null 2>&1
    for _ in 1 2 3 4; do REX_SESSION= "$BIN/rexd" >/dev/null 2>&1 & done
    wait; sleep 1
    ok "R10 four rexd starts at once leave one" "1" "$("$BIN/rexd" status | grep -c '^rexd runs in\|^session:')"
    "$BIN/rexd" stop >/dev/null 2>&1
    # What a start that died leaves: a lock its holder no longer holds.
    mkdir -p "$SB/.local/state/rex-lab"
    lockf -k "$SB/.local/state/rex-lab/rexd.lock" sleep 30 & holder=$!
    sleep 0.5; kill -9 $holder 2>/dev/null; wait $holder 2>/dev/null
    for _ in 1 2 3 4; do REX_SESSION= "$BIN/rexd" >/dev/null 2>&1 & done
    wait; sleep 1
    ok "R10 a start that died leaves no lock behind" "1" "$("$BIN/rexd" status | grep -c '^rexd runs in\|^session:')"
fi

CASE=R11; if want; then
    ok "R11 the live server is untouched" "$LIVE_BEFORE" "$(live_server)"
    ok "R11 no real record names a sandbox path" "0" "$(grep -l "$SB" "$REAL_HOME/.local/state/rex-lab/panes/"*.json 2>/dev/null | wc -l | tr -d ' ')"
fi

echo "rex-resume: $PASS passed, $FAIL failed${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
