#!/usr/bin/env zsh
# Portability of the working-tree zsh package: every machine stows the same
# .zshenv/.zshrc, so they must start clean on a machine that has none of the
# laptop's optional tools, load every module, and differ only by the host file
# ~/.config/machine names (docs/zsh.md § Machines).
#
#   zsh ~/.config/zsh/tests/portability.test.zsh
#
# Requires fzf, zoxide and oh-my-posh, which .zshrc runs on every machine.
#
# The case that bought this suite: the mini once hand-copied part of .zshrc and
# sourced a hand-kept list of modules. Everything added on the laptop after
# that — cout, the Ctrl-D guard, the planlab push wrapper, Claude Code's env —
# silently never reached it.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
ZDOT="$DOT/zsh"
typeset -i PASS=0 FAIL=0
SB="" H=""
typeset -a CLEAN_ENV

[[ -f "$ZDOT/.zshenv" && -f "$ZDOT/.zshrc" ]] || {
  print -u2 "portability.test: no .zshenv/.zshrc at $ZDOT"; exit 1
}

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/port-test-log.XXXXXX")
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

# A bare machine: a throwaway $HOME holding only what stow links from the zsh
# package, plus stand-ins for the two plugin checkouts .zshrc sources from
# $HOME. No ~/.cargo, ~/.bun, tmuxifier, ~/.secrets or ~/.config/machine —
# the laptop-only state every guard must tolerate. ~/.config/zsh links into
# the working tree as stow links it; nothing here writes through it.
sandbox() {
  SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/port-test.XXXXXX")
  H="$SB/home"
  mkdir -p "$H/.config" "$H/.oh-my-zsh" "$H/zsh-syntax-highlighting"
  ln -s "$ZDOT/.config/zsh" "$H/.config/zsh"
  # oh-my-zsh's one duty .zshrc depends on: compinit, so compdef exists.
  print -r -- 'autoload -Uz compinit && compinit -u -d "$HOME/.zcompdump"' \
    >"$H/.oh-my-zsh/oh-my-zsh.sh"
  : >"$H/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  CLEAN_ENV=(env -i HOME="$H" ZDOTDIR="$ZDOT" USER="${USER:-}"
    TERM=xterm-256color TMPDIR="${TMPDIR:-/tmp}" XDG_CACHE_HOME="$H/.cache"
    PATH=/usr/bin:/bin:/usr/sbin:/sbin)
}

# A zsh started from an empty environment: no TMUX, SSH_CONNECTION,
# PROMPT_MACHINE or NVM_DIR leaks in from the shell running the suite (on the
# mini that shell has PROMPT_MACHINE=mini). Caches land in the sandbox.
probe() { command "${CLEAN_ENV[@]}" zsh "$@"; }

# An interactive zsh on a pty, as a terminal starts one. Without a terminal,
# fzf's init fails to set `zle` on any machine, which is noise, not a finding.
# The outer zsh sends the inner one's stderr to $SB/err, so only startup
# errors land there; stdout comes back through script(1) with CRs stripped.
# Prints the line of the result tagged RESULT: and nothing else.
probe_tty() {
  : >"$SB/err"
  script -q /dev/null "${CLEAN_ENV[@]}" zsh -c 'exec 2>"$1"; exec zsh -i -c "$2"' \
    _ "$SB/err" "print -r -- RESULT:$1" </dev/null | tr -d '\r' | sed -n 's/.*RESULT://p'
}

# The sandbox guard. If $HOME did not take, every case below graded the live
# configuration of the machine running the suite, and passed for that reason.
test_sandbox_holds() {
  sandbox
  eq "$H" "$(probe -c 'print -r -- $HOME')" "\$HOME inside the probe" || return 1
  eq "$ZDOT/.config/zsh" "$(probe -c 'print -r -- ${${:-$HOME/.config/zsh}:A}')" \
    "~/.config/zsh inside the probe"
}

# `ssh host cmd`, agents and scripts: .zshenv alone must be silent, because
# its stderr lands in every tool call's output.
test_noninteractive_startup_is_silent() {
  sandbox
  local err rc
  err=$(probe -c true 2>&1 >/dev/null) && rc=0 || rc=$?
  eq "" "$err" "stderr of a non-interactive start" || return 1
  eq "0" "$rc" "exit status"
}

# No allowlist: every module that defines a function reaches every shell. The
# first function each module defines stands in for the module.
test_every_module_loads() {
  sandbox
  local f name
  local -a names
  for f in "$ZDOT"/.config/zsh/*.zsh(N); do
    name=$(sed -nE 's/^([A-Za-z_][A-Za-z0-9_.:-]*)\(\) *\{.*/\1/p' "$f" | head -n 1)
    [[ -n $name ]] && names+=("$name")
  done
  (( ${#names} >= 5 )) || { print -r -- "found only ${#names} module functions"; return 1; }
  local missing
  missing=$(probe -c 'for n in "$@"; do (( $+functions[$n] )) || print -r -- $n; done' _ "${names[@]}")
  eq "" "$missing" "module functions missing after .zshenv"
}

# An interactive shell on the bare machine: .zshrc must reach its last line
# with nothing on stderr. The laptop-only tool lines are what this guards.
test_interactive_startup_is_silent() {
  sandbox
  eq "reached-end" "$(probe_tty reached-end)" "result of an interactive start" || return 1
  eq "" "$(<$SB/err)" "stderr of an interactive start"
}

# What the mini's hand-written copy had lost: the shared behaviour, read off
# an interactive shell rather than grepped from the file.
test_interactive_shell_carries_shared_behaviour() {
  sandbox
  eq "on 1 1 1 1" "$(probe_tty '$options[ignore_eof] $+functions[_guard_ctrl_d] $+functions[git] $+functions[_cout_setup] $CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR')" \
    "ignore_eof, Ctrl-D guard, planlab git wrapper, cout hooks, Claude env"
}

# Without ~/.config/machine no host file loads: no badge, no mini wrappers.
test_no_marker_loads_no_host() {
  sandbox
  eq "unset 0" "$(probe -c 'print -r -- ${PROMPT_MACHINE:-unset} $+functions[aws]')" \
    "PROMPT_MACHINE and the mini's aws wrapper"
}

# The marker selects its tracked host file, in non-interactive shells too.
test_marker_loads_its_host() {
  sandbox
  print mini >"$H/.config/machine"
  eq "mini 1" "$(probe -c 'print -r -- ${PROMPT_MACHINE:-unset} $+functions[aws]')" \
    "PROMPT_MACHINE and the mini's aws wrapper"
}

# A marker naming no host file: silent where stderr is tool output, loud
# where a person reads it.
test_unknown_marker_warns_only_interactively() {
  sandbox
  print nosuchhost >"$H/.config/machine"
  eq "" "$(probe -c true 2>&1)" "non-interactive stderr" || return 1
  local err
  probe_tty x >/dev/null
  err=$(<$SB/err)
  [[ $err == *"hosts/nosuchhost.zsh does not exist"* ]] || {
    print -r -- "interactive stderr lacks the warning: ${(qqq)err}"; return 1
  }
}

t "throwaway \$HOME holds (else everything below is void)"  test_sandbox_holds
t "non-interactive startup is silent on a bare machine"    test_noninteractive_startup_is_silent
t "every module loads, with no allowlist"                  test_every_module_loads
t "interactive startup is silent on a bare machine"        test_interactive_startup_is_silent
t "interactive shell carries the shared behaviour"         test_interactive_shell_carries_shared_behaviour
t "no ~/.config/machine loads no host file"                test_no_marker_loads_no_host
t "~/.config/machine loads its tracked host file"          test_marker_loads_its_host
t "an unknown machine warns only interactively"            test_unknown_marker_warns_only_interactively

rm -rf "${TMPDIR:-/tmp}"/port-test.*(N)
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
