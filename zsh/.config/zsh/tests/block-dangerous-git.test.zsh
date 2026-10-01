#!/usr/bin/env zsh
# Pins claude/.claude/hooks/block-dangerous-git.sh, the PreToolUse(Bash) hook
# that refuses destructive git commands in every Claude session. Drives the
# WORKING-TREE hook with synthetic PreToolUse payloads on stdin; the hook
# reads stdin and writes stderr only, so no sandbox is needed. Exit 2 = the
# hook refused the command (Claude Code shows the model the stderr text),
# exit 0 = passed through.
#
#   zsh ~/.config/zsh/tests/block-dangerous-git.test.zsh
#
# Only decisions that are intended today are pinned. The hook matches text,
# not argv, so some reorderings (`git push origin x --force`, `+ref`, `:ref`)
# slip through; whether those should block is an open policy question, so no
# case asserts either answer.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
HOOK="$DOT/claude/.claude/hooks/block-dangerous-git.sh"
typeset -i PASS=0 FAIL=0

[[ -x "$HOOK" ]] || { print -u2 "block-dangerous-git.test: no executable hook at $HOOK"; exit 1 }

payload() { jq -cn --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' }

# t <want-exit> <command>
t() {
  local want="$1" cmd="$2" rc err
  err=$(payload "$cmd" | "$HOOK" 2>&1 >/dev/null); rc=$?
  if (( rc == want )); then
    (( PASS++ )) || true; print -r -- "PASS ($rc) ${cmd//$'\n'/⏎}"
  else
    (( FAIL++ )) || true; print -r -- "FAIL want=$want got=$rc  ${cmd//$'\n'/⏎}"
    print -r -- "$err" | sed 's/^/    /'
  fi
}

# --- force, delete and mirror pushes: never allowed ---------------------------
t 2 "git push --force"
t 2 "git push -f origin feat"
t 2 "git push --force-with-lease origin feat"
t 2 "git push --delete origin feat"
t 2 "git push --mirror origin"
t 2 "git -C /tmp/p push --force"
# Hooks on one matcher run independently: the dormant bypass-cd guard passing
# this through must not let it run (docs/bypass-cd-read-guard.md).
t 2 "cd /tmp/p; git push --force"

# --- work-destroying commands: never allowed ----------------------------------
t 2 "git reset --hard"
t 2 "git fetch && git reset --hard origin/main"
t 2 "git -C /tmp/p reset --hard"
t 2 "git clean -fd"
t 2 "git clean -f"
t 2 "git checkout ."
t 2 "git restore ."

# --- force branch delete: gated, with a per-command bypass --------------------
t 2 "git branch -D feat"
t 2 "git fetch; git branch -D feat"
t 0 "CLAUDE_ALLOW_BRANCH_DELETE=1 git branch -D feat"
t 0 "git branch -d feat"

# --- ordinary pushes go through, trunk included -------------------------------
t 0 "git push"
t 0 "git push -u origin feat"
t 0 "git push origin main"
t 0 "cd /tmp/p && git push origin HEAD"
t 0 "git stash push -m wip"

# --- inert text: a dangerous phrase that is not executed ----------------------
t 0 "git commit -m 'never git push --force here'"
t 0 "git commit -m \"undo with git reset --hard\""
t 0 "echo 'git branch -D feat'"
t 0 $'git commit -F - <<\'EOF\'\nwhy git clean -fd is blocked\nEOF'

# --- the messages tell the model what to do ------------------------------------
msg=$(payload "git push --force" | "$HOOK" 2>&1 >/dev/null) || true
if [[ "$msg" == *"git push --force"* && "$msg" == *"NEVER bypassable"* ]]; then
  (( PASS++ )) || true; print -r -- "PASS force-push message names the command and says it cannot be bypassed"
else
  (( FAIL++ )) || true; print -r -- "FAIL force-push message"; print -r -- "$msg" | sed 's/^/    /'
fi
msg=$(payload "git branch -D feat" | "$HOOK" 2>&1 >/dev/null) || true
if [[ "$msg" == *"CLAUDE_ALLOW_BRANCH_DELETE=1 git branch -D"* && "$msg" == *"git branch -d"* ]]; then
  (( PASS++ )) || true; print -r -- "PASS branch-delete message gives the bypass and the -d alternative"
else
  (( FAIL++ )) || true; print -r -- "FAIL branch-delete message"; print -r -- "$msg" | sed 's/^/    /'
fi

print -- "----"
print -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
