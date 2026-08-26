#!/usr/bin/env zsh
# Startup-option invariants of the working-tree .zshenv. Deliberately small:
# it starts a real zsh the way every non-interactive caller does — .zshenv and
# nothing else — against a throwaway $HOME, and asserts the option state that
# agent-authored command strings depend on.
#
#   zsh ~/.config/zsh/tests/startup-options.test.zsh
#
# The case that bought this suite: zsh's EQUALS expansion turns `echo ====` —
# a section separator every AI agent writes out of bash habit — into a lookup
# for a command named `===`. That fails, and because the tool wraps the whole
# string in `eval`, the rest of the line silently never runs. 947 truncated
# tool calls across 260 sessions before anyone read the last line of the
# output. This suite goes red if EQUALS comes back, or if the option is moved
# to .zshrc, where non-interactive shells would never see it.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
ZDOT="$DOT/zsh"
typeset -i PASS=0 FAIL=0
SB="" H=""

[[ -f "$ZDOT/.zshenv" ]] || {
  print -u2 "startup-options.test: no .zshenv at $ZDOT"; exit 1
}

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/so-test-log.XXXXXX")
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

# A throwaway $HOME, because .zshenv reads it: it sources ~/.cargo/env
# unguarded and globs ~/.config/zsh/*.zsh. Without the override this suite
# would load the user's live modules — production code with opinions, which
# is not what it grades.
sandbox() {
  SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/so-test.XXXXXX")
  H="$SB/home"
  mkdir -p "$H/.cargo"
  : >"$H/.cargo/env"
}

# One non-interactive, non-login zsh: it reads $ZDOTDIR/.zshenv and nothing
# else — the same startup path the Bash tool, `ssh host cmd` and any script
# take. The working tree's .zshenv, never the stowed copy.
probe() { HOME="$H" ZDOTDIR="$ZDOT" command zsh -c "$1"; }

# The sandbox guard. If $HOME did not take, every other case below graded the
# user's live configuration instead of this checkout — and passed for the
# wrong reason.
test_sandbox_holds() {
  sandbox
  eq "$H" "$(probe 'print -r -- $HOME')" "\$HOME inside the probe"
}

# The invariant itself, read off the option table rather than inferred from
# behaviour.
test_equals_is_off() {
  sandbox
  eq "off" "$(probe 'print -r -- $options[equals]')" "EQUALS after .zshenv"
}

# What the option is for: a compound command with a bash-style separator,
# wrapped in eval exactly as the agent tool wraps it. Asserting the whole
# output, not just the exit status — the failure mode is truncation, and a
# truncated run can still exit 0 if the last command succeeds.
test_separator_does_not_truncate() {
  sandbox
  local out rc
  out=$(probe 'eval "echo A; echo ====; echo B"') && rc=0 || rc=$?
  eq $'A\n====\nB' "$out" "output of an eval'd command with a ==== separator" || return 1
  eq "0" "$rc" "exit status"
}

# The documented .zshenv rule (docs/zsh.md, "Lessons learned"): a non-zero
# last statement silently breaks `source ~/.zshenv && …` chains.
test_zshenv_exits_zero() {
  sandbox
  eq "ok" "$(probe 'source $ZDOTDIR/.zshenv && print -r -- ok')" "source .zshenv && …"
}

# The blast-radius claim that made NO_EQUALS acceptable: `=(...)` process
# substitution is a separate feature and must survive. If this goes red, the
# option was traded for more than it was meant to buy.
test_process_substitution_survives() {
  sandbox
  eq "ok" "$(probe 'diff =(echo a) =(echo a) >/dev/null && print -r -- ok')" "diff =(…) =(…)"
}

t "throwaway \$HOME holds (else everything below is void)" test_sandbox_holds
t "EQUALS is off for non-interactive shells"               test_equals_is_off
t "a ==== separator does not truncate an eval'd command"   test_separator_does_not_truncate
t ".zshenv still exits 0"                                  test_zshenv_exits_zero
t "=(…) process substitution still works"                  test_process_substitution_survives

rm -rf "${TMPDIR:-/tmp}"/so-test.*(N)
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
