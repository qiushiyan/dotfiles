#!/usr/bin/env zsh
# The protected-path guard of the working-tree utils.zsh's rm(): a recursive
# delete of $HOME, /, a system root or a listed home dir is refused, whatever
# spelling reaches it (a trailing slash, a `..`, a symlink, a literal ~, or
# macOS's /var → /private/var), and every other call passes through.
#
#   zsh ~/.config/zsh/tests/rm-guard.test.zsh
#
# Every probe is a `zsh -f` whose PATH is the sandbox's bin alone, holding a
# stub rm that only logs its arguments: `command rm` cannot reach the real
# binary, so a guard that fails to block deletes nothing. The first case
# checks that before any other runs.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
MOD="$DOT/zsh/.config/zsh/utils.zsh"
ZSH_BIN=$(whence -p zsh)
typeset -i PASS=0 FAIL=0

[[ -f "$MOD" ]] || { print -u2 "rm-guard.test: no utils.zsh at $MOD"; exit 1 }

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/rg-test-log.XXXXXX")
  if "$@" >"$log" 2>&1; then
    (( PASS++ )) || true
    print -r -- "PASS $name"
  else
    (( FAIL++ )) || true
    print -r -- "FAIL $name"
    sed 's/^/    /' "$log"
  fi
  command rm -f "$log"
}

# A throwaway $HOME (the guard protects $HOME, so it must be one the suite
# owns), a symlink to it, and the logging stub. $SB is resolved (:A) once so
# the paths the stub logs compare equal to the ones the cases pass.
SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/rg-test.XXXXXX") || exit 1
SB=${SB:A}   # never empty here: ${:-""}:A would be the cwd the final delete hits
[[ "$SB" == /*/rg-test.* ]] || { print -u2 "rm-guard.test: bad sandbox ${(qqq)SB}"; exit 1 }
H="$SB/home"
mkdir -p "$H/sub" "$SB/bin"
ln -s "$H" "$SB/home-link"
print -r -- '#!/bin/sh
printf "%s\n" "$*" >> "'"$SB"'/rm.log"' >"$SB/bin/rm"
chmod +x "$SB/bin/rm"

# probe <rm args...>: the module's rm in a shell that can only find the stub.
probe() {
  HOME="$H" PATH="$SB/bin" "$ZSH_BIN" -f -c 'source "$1"; shift; rm "$@"' zsh "$MOD" "$@"
}

test_only_the_stub_is_reachable() {
  local got
  got=$(HOME="$H" PATH="$SB/bin" "$ZSH_BIN" -f -c 'source "$1"; whence -p rm' zsh "$MOD")
  [[ "$got" == "$SB/bin/rm" ]] || { print -r -- "command rm resolves to ${(qqq)got}, not the stub"; return 1 }
}

# Each row: the flags, then the target.
test_protected_paths_are_refused() {
  local flags target rc err bad=0
  for flags target in \
      -rf "$H"            -rf "$H/"          -rf "$H/sub/.." \
      -rf "$SB/home-link" -rf '~'            -R  "$H" \
      --recursive "$H"    -rf /var           -rf /etc \
      -rf /usr            -rf /; do
    : >| "$SB/rm.log"
    rc=0
    err=$(probe $flags "$target" 2>&1) || rc=$?
    if (( rc != 1 )) || [[ -s "$SB/rm.log" || "$err" != *Blocked* ]]; then
      print -r -- "rm $flags $target: rc=$rc, reached rm: $(<"$SB/rm.log"), stderr: $err"
      bad=1
    fi
  done
  return bad
}

test_other_calls_pass_through() {
  local flags target bad=0
  for flags target in \
      -rf "$H/sub"   -rf "$H/missing/a"   -f "$H"   -- -r; do
    : >| "$SB/rm.log"
    probe $flags "$target" 2>/dev/null
    if [[ "$(<"$SB/rm.log")" != "$flags $target" ]]; then
      print -r -- "rm $flags $target did not reach rm unchanged; logged: $(<"$SB/rm.log")"
      bad=1
    fi
  done
  return bad
}

t "only the logging stub rm is reachable (else the rest is unsafe)" test_only_the_stub_is_reachable
if (( FAIL )); then
  print -u2 "rm-guard.test: sandbox isolation failed; not running the delete cases"
  exit 1
fi
t "recursive rm of a protected path is refused, in every spelling" test_protected_paths_are_refused
t "everything else reaches rm unchanged"                           test_other_calls_pass_through

command rm -rf -- "$SB"
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
