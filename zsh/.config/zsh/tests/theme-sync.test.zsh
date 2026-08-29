#!/usr/bin/env zsh
# Live-switch contract of the working-tree theme.zsh. Deliberately small: it
# sources the module into a real interactive `zsh -f` against a throwaway
# $HOME and asserts the three things docs/theming.md promises — startup reads
# the state file (not an inherited env value), the _theme_sync precmd
# re-applies when the file changes under a running shell, and the hook is
# registered ahead of any prompt renderer that comes later.
#
#   zsh ~/.config/zsh/tests/theme-sync.test.zsh
#
# The case that bought this suite: switching themes from `prefix t` while
# `claude` held a shell in the foreground. That shell drew its first prompt
# after claude exited in the old palette — oh-my-posh renders from the shell's
# env, and the env was a startup snapshot — until `exec zsh`.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
MOD="$DOT/zsh/.config/zsh/theme.zsh"
typeset -i PASS=0 FAIL=0
SB="" H=""

[[ -f "$MOD" ]] || { print -u2 "theme-sync.test: no theme.zsh at $MOD"; exit 1 }

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/ts-test-log.XXXXXX")
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

# A throwaway $HOME with its own state file, because theme.zsh reads
# $HOME/.config/terminal-theme. Without the override every case below would
# read — and the sync case would WRITE — the user's live theme.
sandbox() {  # sandbox <initial theme name>
  SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/ts-test.XXXXXX")
  H="$SB/home"
  mkdir -p "$H/.config"
  print -r -- "$1" >"$H/.config/terminal-theme"
}

# One interactive zsh with no startup files (-f), fed a script on stdin. -i is
# what makes the module register its precmd; the prompt noise goes to stderr,
# which is dropped. The working tree's theme.zsh, never the stowed copy.
probe() { HOME="$H" TERMINAL_THEME="${2:-}" command zsh -f -i 2>/dev/null <<<"source $MOD
$1
exit" }

test_sandbox_holds() {
  sandbox flexoki_light
  eq "$H" "$(probe 'print -r -- $HOME')" "\$HOME inside the probe"
}

# The file wins over an inherited value — the tmux-server-snapshot bug from
# docs/theming.md Model 3.
test_file_beats_inherited_env() {
  sandbox gruvbox_dark
  eq "gruvbox_dark" "$(probe 'print -r -- $TERMINAL_THEME' catppuccin_mocha)" "startup theme"
}

# The hook is registered in interactive shells, and only there.
test_hook_registered_interactive_only() {
  sandbox flexoki_light
  eq "yes" "$(probe '(( $precmd_functions[(I)_theme_sync] )) && print yes || print no')" "interactive" || return 1
  eq "no" "$(HOME="$H" command zsh -f -c "source $MOD; (( \$precmd_functions[(I)_theme_sync] )) && print yes || print no")" "non-interactive"
}

# The live switch: the file changes under a running shell, the next precmd
# re-applies everything the module owns, not just the name.
test_sync_reapplies_on_change() {
  sandbox vitesse_light_soft
  local out
  out=$(probe 'print -r -- "$TERMINAL_THEME $LSCOLORS $DELTA_FEATURES"
print -r -- night_owl >"$HOME/.config/terminal-theme"
_theme_sync
print -r -- "$TERMINAL_THEME $LSCOLORS $DELTA_FEATURES"')
  eq "vitesse_light_soft exfxcxdxbxegedabagacad +light-mode
night_owl Gxfxcxdxbxegedabagacad +dark-mode" "$out" "before/after a file change"
}

# A hook registered after ours (as oh-my-posh's _omp_precmd is, from the end
# of .zshrc) runs after ours, so it sees the refreshed value.
test_sync_runs_before_later_hooks() {
  sandbox flexoki_light
  eq "night_owl" "$(probe 'autoload -Uz add-zsh-hook
_fake_omp() { print -r -- "$TERMINAL_THEME" }
add-zsh-hook precmd _fake_omp
print -r -- night_owl >"$HOME/.config/terminal-theme"
local f; for f in $precmd_functions; do $f; done' | tail -1)" "value seen by a later precmd"
}

t "throwaway \$HOME holds (else everything below is void)" test_sandbox_holds
t "the state file beats an inherited TERMINAL_THEME"        test_file_beats_inherited_env
t "_theme_sync is registered in interactive shells only"    test_hook_registered_interactive_only
t "a file change is re-applied at the next precmd"          test_sync_reapplies_on_change
t "_theme_sync runs ahead of later-registered precmds"      test_sync_runs_before_later_hooks

rm -rf "${TMPDIR:-/tmp}"/ts-test.*(N)
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
