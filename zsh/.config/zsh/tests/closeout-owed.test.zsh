#!/usr/bin/env zsh
# Pins claude/.claude/hooks/closeout-owed.py, the PostToolUse(Bash) and Stop
# hook that reminds a session which merged a PR, once, that closing it out is
# its own next step.
# Drives the WORKING-TREE hook with synthetic payloads on stdin. Stop prints
# one JSON document with additionalContext when it reminds, nothing otherwise;
# PostToolUse prints nothing.
#
#   zsh ~/.config/zsh/tests/closeout-owed.test.zsh
#
# ISOLATION. The hook runs under `env -i` with HOME and XDG_STATE_HOME inside
# this suite's sandbox and a PATH of the sandbox's bin and /usr/bin:/bin, where
# `gh` is a stub that prints a chosen state and logs its arguments, so the real
# gh never runs. Session ids carry this run's pid, and the last case asserts
# none of them reached the real state directory.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
HOOK="$DOT/claude/.claude/hooks/closeout-owed.py"
typeset -i PASS=0 FAIL=0 NSID=0
typeset OUT="" SID=""

[[ -x "$HOOK" ]] || { print -u2 "closeout-owed.test: no executable hook at $HOOK"; exit 1 }
REAL_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/claude-hooks/closeout-owed"
BARE=/usr/bin:/bin
if env -i PATH="$BARE" /bin/sh -c 'command -v gh' >/dev/null 2>&1; then
  print -u2 "closeout-owed.test: $BARE holds a gh, so no stub can stand in for it"; exit 1
fi

SBX=$(mktemp -d "${TMPDIR:-/tmp}/closeout-owed.XXXXXX") || exit 1
SBX=${SBX:A}
cleanup() {
  [[ -n "$SBX" && "$SBX" == /* && ( "$SBX" == /private/var/folders/* || "$SBX" == /private/tmp/* ) ]] \
    && rm -rf -- "$SBX"
}
trap cleanup EXIT
cd "$SBX" || exit 1

H="$SBX/home"; STATE="$SBX/state"; BIN="$SBX/bin"
WT="$H/dev/.worktrees/main/loopy/memory-saves"; MAIN="$H/dev/planlab/main"; OTHER="$H/dev/itell"
mkdir -p "$BIN" "$WT" "$MAIN" "$OTHER"
typeset -a HOOK_ENV=(HOME="$H" XDG_STATE_HOME="$STATE" PATH="$BIN:$BARE")
typeset -aU PYS=(${commands[python3]} /usr/bin/python3(N))

pass() { (( PASS++ )) || true; print -r -- "PASS $1" }
fail() { (( FAIL++ )) || true; print -r -- "FAIL $1"; [[ -z "${2-}" ]] || print -r -- "    $2" }

# gh_says <state> [number]: a gh stub answering `gh pr view` with that state.
gh_says() {
  print -r -- "#!/bin/sh
echo \"\$*\" >> '$SBX/gh.args'
echo '{\"number\": ${2:-12139}, \"state\": \"$1\"}'" > "$BIN/gh"
  chmod +x "$BIN/gh"
}

new_sid() { (( NSID++ )); SID="co-test-$$-$NSID" }

# bash <py> <cwd> <command>: a PostToolUse(Bash) payload.
bash_ran() {
  local py=$1 cwd=$2 cmd=$3
  OUT=$(python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"PostToolUse","tool_name":"Bash","session_id":sys.argv[1],"cwd":sys.argv[2],"tool_input":{"command":sys.argv[3]}}))' "$SID" "$cwd" "$cmd" \
    | env -i $HOOK_ENV "$py" "$HOOK")
}
stop() {
  local py=$1 cwd=$2
  OUT=$(python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"Stop","session_id":sys.argv[1],"cwd":sys.argv[2],"stop_hook_active":False}))' "$SID" "$cwd" \
    | env -i $HOOK_ENV "$py" "$HOOK")
}
reminded() { [[ "$OUT" == *'"additionalContext"'* && "$OUT" == *"$1 merged in this session"* && "$OUT" == *'pl-closeout/SKILL.md'* ]] }

for PY in $PYS; do
  v=$("$PY" -c 'import sys; print("%d.%d" % sys.version_info[:2])')

  # H1: a background land-wait merge, then the turn ends with the PR merged: one reminder, then silence
  new_sid; gh_says MERGED; : > "$SBX/gh.args"
  bash_ran "$PY" "$WT" '.agents/skills/pl-land/scripts/land-wait.sh 12139 --merge > /tmp/x/land-wait.txt 2>&1'
  [[ -z "$OUT" ]] && pass "H1 [$v] the merge prints nothing" || fail "H1 [$v] the merge prints nothing" "$OUT"
  stop "$PY" "$WT"
  reminded '#12139' && pass "H1 [$v] the merged PR is reminded, naming the skill's file" || fail "H1 [$v] reminder" "$OUT"
  stop "$PY" "$WT"
  [[ -z "$OUT" ]] && pass "H1 [$v] a second turn end is silent" || fail "H1 [$v] once" "$OUT"

  # H2: still open at the turn end: silent and still owed; merged at a later turn end: reminded
  new_sid; gh_says OPEN
  bash_ran "$PY" "$WT" 'land-wait.sh 12139 --merge'
  stop "$PY" "$WT"
  [[ -z "$OUT" ]] && pass "H2 [$v] an open PR is silent" || fail "H2 [$v] open" "$OUT"
  gh_says MERGED; stop "$PY" "$WT"
  reminded '#12139' && pass "H2 [$v] it is reminded once it merged" || fail "H2 [$v] later" "$OUT"

  # H3: the closeout check ran for the PR: no reminder, and GitHub is not asked
  new_sid; gh_says MERGED; : > "$SBX/gh.args"
  bash_ran "$PY" "$MAIN" 'gh pr merge 12139 --squash --match-head-commit abc'
  bash_ran "$PY" "$MAIN" 'python3 ~/.local/share/dotfiles/planlab-skills/pl-closeout/scripts/closeout_check.py 12139'
  stop "$PY" "$MAIN"
  [[ -z "$OUT" && ! -s "$SBX/gh.args" ]] && pass "H3 [$v] a begun closeout is not reminded or asked" || fail "H3 [$v] begun" "$OUT $(cat $SBX/gh.args)"

  # H4: outside every project nothing is recorded
  new_sid; gh_says MERGED
  bash_ran "$PY" "$OTHER" 'gh pr merge 5 --squash'
  stop "$PY" "$OTHER"
  [[ -z "$OUT" && ! -e "$STATE/claude-hooks/closeout-owed/$SID.json" ]] && pass "H4 [$v] another project is ignored" || fail "H4 [$v] other" "$OUT"

  # H5: a merge by URL, and a bare one that names the branch's own PR
  new_sid; gh_says MERGED 777
  bash_ran "$PY" "$WT" 'cd /x && gh pr merge https://github.com/o/r/pull/777 --squash'
  stop "$PY" "$WT"
  reminded '#777' && pass "H5 [$v] a URL names its PR" || fail "H5 [$v] url" "$OUT"
  new_sid; gh_says OPEN 888
  bash_ran "$PY" "$WT" 'gh pr merge --squash'
  gh_says MERGED 888; stop "$PY" "$WT"
  reminded '#888' && pass "H5 [$v] a bare merge takes the branch's PR" || fail "H5 [$v] bare" "$OUT"

  # H6: closed unmerged: dropped, never reminded
  new_sid; gh_says CLOSED
  bash_ran "$PY" "$WT" 'land-wait.sh 12139 --merge'
  stop "$PY" "$WT"; gh_says MERGED; stop "$PY" "$WT"
  [[ -z "$OUT" ]] && pass "H6 [$v] a PR closed unmerged is dropped" || fail "H6 [$v] closed" "$OUT"

  # H7: text that only mentions a merge, and a wait without --merge, record nothing
  new_sid; gh_says MERGED
  bash_ran "$PY" "$WT" "echo 'gh pr merge 12139' && land-wait.sh 12139"
  stop "$PY" "$WT"
  [[ -z "$OUT" ]] && pass "H7 [$v] a mention or a wait is not a merge" || fail "H7 [$v] inert" "$OUT"

  # H8: no gh at all: silent
  new_sid; rm -f "$BIN/gh"
  bash_ran "$PY" "$WT" 'land-wait.sh 12139 --merge'
  stop "$PY" "$WT"
  [[ -z "$OUT" ]] && pass "H8 [$v] no gh, no word" || fail "H8 [$v] no gh" "$OUT"
done

stale=("$REAL_STATE"/co-test-$$-*(N))
(( $#stale == 0 )) && pass "H9 the real state directory holds no test record" || fail "H9 real state" "${stale[*]}"

print -r -- "PASS $PASS  FAIL $FAIL"
(( FAIL == 0 ))
