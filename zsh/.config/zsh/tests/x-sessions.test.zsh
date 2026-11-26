#!/usr/bin/env zsh
# What x-sessions (claude.zsh) does with the session picked: it resumes it by
# id through x, so headroom gets `--resume <id>` after x's own args, from the
# directory claude-sessions names, and the shell stays there; with nowhere to
# go it resumes where it was and says so. Esc, a bad --days and an empty
# store launch nothing, and a session a running claude has open is resumed
# only on a yes typed at the terminal. Which sessions are listed and where
# each resumes is claude-sessions' contract, tested in
# scripts/.local/share/dotfiles/tests/test_claude_sessions.py.
#
#   zsh ~/.config/zsh/tests/x-sessions.test.zsh
#
# Each probe is a `zsh -f` sourcing the working tree's claude.zsh, with a
# throwaway $HOME holding fixture transcripts, the working tree's
# claude-sessions, a stub fzf that picks the row it is told to, and a stub
# headroom that only records its arguments and directory, so no session
# starts and no real store is read.

emulate -L zsh
setopt pipe_fail no_unset
zmodload zsh/datetime

DOT="${0:A:h:h:h:h:h}"
MODS="$DOT/zsh/.config/zsh"
ZSH_BIN=$(whence -p zsh)
PYTHON=$(whence -p python3)
typeset -i PASS=0 FAIL=0

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/xs-test-log.XXXXXX")
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

# A fresh $HOME and the stubs. Sets SB and H.
sandbox() {
  SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/xs-test.XXXXXX") || return 1
  SB=${SB:A}
  H="$SB/home"
  mkdir -p "$SB/bin" "$SB/start" "$H/.claude/projects" "$H/.claude-accounts"
  ln -s "$DOT/scripts/.local/bin/claude-sessions" "$SB/bin/claude-sessions"
  ln -s "$PYTHON" "$SB/bin/python3"
  cat >"$SB/bin/headroom" <<EOS
#!/bin/sh
pwd -P > "$SB/headroom.pwd"
printf '%s\n' "\$*" > "$SB/headroom.log"
EOS
  # FZF_PICK: the id of the row to pick, or esc.
  cat >"$SB/bin/fzf" <<EOS
#!/bin/sh
printf '%s\n' "\$@" > "$SB/fzf.args"
[ "\${FZF_PICK-}" = esc ] && exit 130
while IFS= read -r line; do
  case "\$line" in "\$FZF_PICK"*) printf '%s\n' "\$line"; exit 0 ;; esac
done
exit 1
EOS
  chmod +x "$SB/bin/headroom" "$SB/bin/fzf"
}

# session <id> <cwd>: an interactive transcript that last ran in <cwd>.
session() {
  local id=$1 cwd=$2
  local dir="$H/.claude/projects/${cwd//[^A-Za-z0-9]/-}"
  mkdir -p $dir
  print -r -- '{"type":"user","entrypoint":"cli","cwd":"'$cwd'","sessionId":"'$id'","gitBranch":"main","message":{"role":"user","content":"hi"}}' >$dir/$id.jsonl
  print -r -- '{"type":"ai-title","aiTitle":"Session '${id[1,8]}'","sessionId":"'$id'"}' >>$dir/$id.jsonl
}

# probe <script>: claude.zsh sourced as .zshenv does, then <script>, from
# $SB/start; prints the shell's directory and the script's status after it.
probe() {
  env -u TMUX -u TMUX_PANE -u XDG_CACHE_HOME -u CLAUDE_CONFIG_DIR -u REX_BLOCK -u REX_SERVER \
      -u TERM_PROGRAM -u CLAUDE_PID -u NO_COLOR \
      HOME="$H" PATH="$SB/bin:/usr/bin:/bin" "$ZSH_BIN" -f -c '
    cd -q -- $2/start || exit 1
    source $1/claude.zsh
    eval $3
    print -r -- "status => $?"
    print -r -- "pwd => ${PWD:A}"
    ' zsh "$MODS" "$SB" "$1"
}

launched() { [[ -e "$SB/headroom.log" ]] && print -r -- "$(<$SB/headroom.log) @ $(<$SB/headroom.pwd)" }

A=11111111-1111-4111-8111-111111111111
B=22222222-2222-4222-8222-222222222222
C=33333333-3333-4333-8333-333333333333
D=44444444-4444-4444-8444-444444444444

# The pick resumes by id after x's args, at the checkout root of where it ran,
# and the shell stays there.
test_pick_resumes_in_its_checkout() {
  sandbox || return 1
  mkdir -p "$H/dev/alpha/.git" "$H/dev/alpha/apps/web"
  session $A "$H/dev/alpha/apps/web"
  local out; out=$(FZF_PICK=$A probe 'x-sessions --fast')
  local want="launch -- --settings {\"fastMode\":true} --dangerously-skip-permissions --resume $A @ $H/dev/alpha"
  [[ "$(launched)" == "$want" ]] || { print -r -- "launched: $(launched)"; print -r -- "want:     $want"; return 1 }
  [[ "$out" == *"status => 0"* && "$out" == *"pwd => $H/dev/alpha"* ]] || { print -r -- "$out"; return 1 }
  # fzf shows the row, not the id and pid in front of it, and previews by id.
  [[ "$(<$SB/fzf.args)" == *"--with-nth=3.."* && "$(<$SB/fzf.args)" == *"--preview=claude-sessions preview {1}"* ]] \
    || { print -r -- "fzf got: $(<$SB/fzf.args)"; return 1 }
}

test_x_resume_is_x_sessions() {
  sandbox || return 1
  mkdir -p "$H/dev/alpha/.git"
  session $A "$H/dev/alpha"
  FZF_PICK=$A probe 'x-resume --model claude-fable-5-2' >/dev/null
  local want="launch -- --dangerously-skip-permissions --model claude-fable-5-2 --resume $A @ $H/dev/alpha"
  [[ "$(launched)" == "$want" ]] || { print -r -- "launched: $(launched)"; return 1 }
}

# A worktree removed since: its main checkout, as claude-sessions finds it.
test_a_removed_worktree_resumes_in_its_main_checkout() {
  sandbox || return 1
  mkdir -p "$H/dev/planlab/main/.git" "$H/.config/gwt"
  print -r -- 'worktree_root = "~/dev/.worktrees"' >"$H/.config/gwt/config.toml"
  session $B "$H/dev/.worktrees/main/feat/x"
  local out; out=$(FZF_PICK=$B probe 'x-sessions' 2>&1)
  [[ "$(launched)" == *"--resume $B @ $H/dev/planlab/main" ]] || { print -r -- "launched: $(launched)"; return 1 }
  [[ "$out" == *"is gone; resuming in its main checkout, ~/dev/planlab/main"* ]] || { print -r -- "$out"; return 1 }
}

# Nowhere to go: it resumes where the shell is, and says so.
test_nowhere_resumes_here() {
  sandbox || return 1
  session $C "/no/such/place"
  local out; out=$(FZF_PICK=$C probe 'x-sessions' 2>&1)
  [[ "$(launched)" == *"--resume $C @ $SB/start" ]] || { print -r -- "launched: $(launched)"; return 1 }
  [[ "$out" == *"x-sessions: resuming in $SB/start"* ]] || { print -r -- "$out"; return 1 }
}

test_esc_launches_nothing() {
  sandbox || return 1
  session $A "$H"
  local out; out=$(FZF_PICK=esc probe 'x-sessions')
  [[ ! -e "$SB/headroom.log" && "$out" == *"status => 0"* && "$out" == *"pwd => $SB/start"* ]] \
    || { print -r -- "$out / $(launched)"; return 1 }
}

test_refusals_launch_nothing() {
  sandbox || return 1
  local out
  out=$(FZF_PICK=$A probe 'x-sessions' 2>&1)
  [[ "$out" == *"no interactive Claude Code session in the last 14 days"* && "$out" == *"status => 1"* ]] \
    || { print -r -- "empty store: $out"; return 1 }
  session $A "$H"
  out=$(FZF_PICK=$A probe 'x-sessions --days soon' 2>&1)
  [[ "$out" == *"--days takes a whole number"* && "$out" == *"status => 2"* ]] \
    || { print -r -- "bad --days: $out"; return 1 }
  [[ ! -e "$SB/headroom.log" && ! -e "$SB/fzf.args" ]] || { print -r -- "something ran"; return 1 }
  out=$(FZF_PICK=$A probe 'x-sessions --days 0' 2>&1)
  [[ "$(launched)" == *"--resume $A @ $H" ]] || { print -r -- "--days 0: $(launched)"; return 1 }
}

# A session a running claude has open: no yes, no resume; a y at the
# terminal resumes it.
test_an_open_session_asks_first() {
  sandbox || return 1
  mkdir -p "$H/dev/alpha/.git" "$H/.claude-accounts/a@example.com/sessions"
  session $D "$H/dev/alpha"
  sleep 60 &!
  local pid=$!
  local ms; ms=$("$PYTHON" -c 'import sys, time; print(int(time.mktime(time.strptime(sys.argv[1].strip(), "%a %b %d %H:%M:%S %Y")) * 1000))' \
    "$(LC_ALL=C ps -o lstart= -p $pid)") || return 1
  print -r -- '{"pid":'$pid',"sessionId":"'$D'","cwd":"'$H'/dev/alpha","startedAt":'$ms'}' \
    >"$H/.claude-accounts/a@example.com/sessions/$pid.json"
  local out rc=0
  out=$(FZF_PICK=$D probe 'x-sessions' 2>&1 </dev/null)
  [[ ! -e "$SB/headroom.log" && "$out" == *"has this session open"* && "$out" == *"status => 1"* ]] \
    || { print -r -- "without a yes: $out / $(launched)"; rc=1 }
  # On a pty, the y reaches read -q.
  (sleep 2; print -n y) | FZF_PICK=$D script -q /dev/null "$ZSH_BIN" -f -c "$(functions probe)
    $(typeset -p SB H MODS ZSH_BIN); probe x-sessions" >/dev/null 2>&1
  [[ "$(launched)" == *"--resume $D @ $H/dev/alpha" ]] || { print -r -- "with a yes: $(launched)"; rc=1 }
  kill $pid 2>/dev/null
  return rc
}

# A same-named account's launcher never replaces the picker.
test_accounts_do_not_take_the_names() {
  sandbox || return 1
  mkdir -p "$H/.claude-accounts/sessions@a.com" "$H/.claude-accounts/resume@a.com"
  local out; out=$(probe 'print -r -- "${functions[x-sessions]}" | grep -c "claude-sessions list"
    print -r -- "${functions[x-resume]}"
    (( $+functions[x-sessions@a.com] )) && print -r -- full-launcher')
  [[ "$out" == 1$'\n'*x-sessions*$'\n'full-launcher* ]] || { print -r -- "$out"; return 1 }
}

t "the pick resumes by id in its checkout, after x's args"   test_pick_resumes_in_its_checkout
t "x-resume is x-sessions"                                   test_x_resume_is_x_sessions
t "a removed worktree resumes in its main checkout"          test_a_removed_worktree_resumes_in_its_main_checkout
t "with nowhere to go it resumes here and says so"           test_nowhere_resumes_here
t "Esc launches nothing"                                     test_esc_launches_nothing
t "an empty store and a bad --days launch nothing"           test_refusals_launch_nothing
t "an open session resumes only on a yes"                    test_an_open_session_asks_first
t "an account named sessions or resume keeps the picker"     test_accounts_do_not_take_the_names

rm -rf "${TMPDIR:-/tmp}"/xs-test.*(N)
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
