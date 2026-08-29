#!/usr/bin/env zsh
# Deleted-cwd contract of the working-tree cwd-guard.zsh. Deliberately small:
# every probe is a real `zsh -f` started from a directory the case has just
# deleted, against a throwaway $HOME, sourcing the module the way .zshenv
# does. It asserts what docs/zsh.md promises — an interactive shell that
# starts in a dead directory is moved to ~ before any prompt, a
# non-interactive one is left alone, a live cwd is never touched, and
# zshreload relocates to the nearest surviving ancestor before it execs.
#
#   zsh ~/.config/zsh/tests/cwd-guard.test.zsh
#
# The case that bought this suite: `zshreload` from a pane whose git worktree
# had been removed. The exec'd zsh came up with PWD="." and
# zsh-syntax-highlighting's path check spun forever on `.:h == .` at the first
# keystroke — 100% CPU, pane unresponsive, for six hours.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
MOD="$DOT/zsh/.config/zsh/cwd-guard.zsh"
typeset -i PASS=0 FAIL=0
SB="" H=""

[[ -f "$MOD" ]] || { print -u2 "cwd-guard.test: no cwd-guard.zsh at $MOD"; exit 1 }

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/cg-test-log.XXXXXX")
  if "$@" >"$log" 2>&1; then
    (( PASS++ )) || true
    print -r -- "PASS $name"
  else
    (( FAIL++ )) || true
    print -r -- "FAIL $name"
    sed 's/^/    /' "$log"
  fi
  rm -f "$log"
}

eq() {  # eq <expected> <actual> <what>
  [[ "$1" == "$2" ]] && return 0
  print -r -- "$3: expected ${(qqq)1}, got ${(qqq)2}"
  return 1
}

# A throwaway $HOME, because the guard's recovery target IS $HOME: without the
# override a case would `cd` the probe into the user's real home — harmless
# for a probe, but the point of the suite is to see where it lands, and the
# real home can't be told apart from "the guard did nothing in a shell that
# started there". $SB is resolved (:A) once so $PWD comparisons don't trip on
# macOS's /var → /private/var symlink.
sandbox() {
  SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/cg-test.XXXXXX"); SB=${SB:A}
  H="$SB/home"
  mkdir -p "$H"
}

# probe <mode> <script>: one zsh with no startup files (-f), interactive (-i)
# or not (-c), sourcing the working tree's module first — never the stowed
# copy. Prompt noise from -i goes to stderr, which is dropped; the guard's own
# message goes there too, so cases that want it capture 2>&1 themselves.
probe() {
  case "$1" in
    interactive) HOME="$H" command zsh -f -i 2>/dev/null <<<"source $MOD
$2
exit" ;;
    script)      HOME="$H" command zsh -f -c "source $MOD; $2" 2>/dev/null ;;
  esac
}

# dead_probe <mode> <script>: the probe, started from a directory that no
# longer exists. Runs in a subshell so the deletion never touches the suite's
# own cwd. The zsh that starts there is the reload case exactly: getcwd fails,
# PWD="." — the suite asserts that precondition first (test_precondition).
dead_probe() {
  local dead="$SB/dead/nested"
  mkdir -p "$dead"
  ( cd "$dead" && rm -rf "$SB/dead" && probe "$1" "$2" )
}

test_sandbox_holds() {
  sandbox
  eq "$H" "$(probe interactive 'print -r -- $HOME')" "\$HOME inside the probe"
}

# The precondition every other case rests on: a zsh started in a deleted
# directory really does come up with PWD=".". If this goes red, zsh changed
# and the guard's trigger no longer matches — the suite must not pass anyway.
test_precondition_dead_cwd_is_dot() {
  sandbox
  local dead="$SB/dead"
  mkdir -p "$dead"
  eq "." "$( cd "$dead" && rmdir "$dead" && command zsh -f -c 'print -r -- $PWD' )" "PWD of a zsh started in a deleted dir"
}

# The guard: an interactive shell that starts in a dead directory is in ~ by
# the time its startup script runs the next line — i.e. before any prompt.
test_interactive_dead_cwd_moves_home() {
  sandbox
  eq "$H" "$(dead_probe interactive 'print -r -- $PWD')" "PWD after the module"
}

# ...and it says so, on stderr, so the move is never a silent surprise.
test_guard_announces_the_move() {
  sandbox
  local dead="$SB/dead"; mkdir -p "$dead"
  local out
  out=$( cd "$dead" && rmdir "$dead" && HOME="$H" command zsh -f -i 2>&1 <<<"source $MOD
exit" )
  [[ "$out" == *"cwd-guard: the working directory no longer exists"* ]] && return 0
  print -r -- "expected the guard's message on stderr, got ${(qqq)out}"
  return 1
}

# Scripts are left where they started, dead or not: they have no zle to hang,
# and moving a script's cwd behind its back would be a bug of its own.
test_script_dead_cwd_left_alone() {
  sandbox
  eq "." "$(dead_probe script 'print -r -- $PWD')" "PWD of a non-interactive shell"
}

# A live cwd is never touched, in either mode.
test_live_cwd_untouched() {
  sandbox
  local live="$SB/live"; mkdir -p "$live"
  eq "$live" "$( cd "$live" && probe interactive 'print -r -- ${PWD:A}' )" "interactive" || return 1
  eq "$live" "$( cd "$live" && probe script 'print -r -- ${PWD:A}' )" "script"
}

# The old shell's side: it still holds the full path, so _cwd_relocate walks
# up to the nearest ancestor that exists — $SB here, two levels up — rather
# than giving up and going home.
test_relocate_climbs_to_nearest_ancestor() {
  sandbox
  eq "$SB" "$(probe interactive 'cd '"$SB"'/dead/nested 2>/dev/null || { mkdir -p '"$SB"'/dead/nested && cd '"$SB"'/dead/nested }
rm -rf '"$SB"'/dead
_cwd_relocate
print -r -- ${PWD:A}')" "PWD after _cwd_relocate"
}

# ...and does nothing while the cwd is intact — no cd, and no message. stderr
# also carries the -i prompt noise, so the message is asserted absent rather
# than the stream asserted empty.
test_relocate_noop_on_live_cwd() {
  sandbox
  local live="$SB/live"; mkdir -p "$live"
  local out
  out=$( cd "$live" && HOME="$H" command zsh -f -i 2>&1 <<<"source $MOD
_cwd_relocate
print -r -- \${PWD:A}
exit" )
  [[ "$out" == *"cwd-guard:"* ]] && { print -r -- "unexpected message: ${(qqq)out}"; return 1 }
  [[ "$out" == *"$live"* ]] && return 0
  print -r -- "expected the live cwd in the output, got ${(qqq)out}"
  return 1
}

# zshreload is the relocate followed by the exec — checked as a contract on
# the function body, since actually running it would exec over the probe.
test_zshreload_relocates_before_exec() {
  sandbox
  eq "yes" "$(probe interactive '[[ $functions[zshreload] == *_cwd_relocate*exec\ zsh\ -l* ]] && print yes || print no')" "zshreload body: _cwd_relocate, then exec zsh -l"
}

t "throwaway \$HOME holds (else everything below is void)"      test_sandbox_holds
t "precondition: a zsh started in a deleted dir has PWD=\".\""  test_precondition_dead_cwd_is_dot
t "interactive shell in a dead cwd is moved to ~"                test_interactive_dead_cwd_moves_home
t "the move is announced on stderr"                              test_guard_announces_the_move
t "non-interactive shell in a dead cwd is left alone"            test_script_dead_cwd_left_alone
t "a live cwd is never touched"                                  test_live_cwd_untouched
t "_cwd_relocate climbs to the nearest surviving ancestor"       test_relocate_climbs_to_nearest_ancestor
t "_cwd_relocate is a silent no-op on a live cwd"                test_relocate_noop_on_live_cwd
t "zshreload relocates before it execs"                          test_zshreload_relocates_before_exec

rm -rf "${TMPDIR:-/tmp}"/cg-test.*(N)
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
