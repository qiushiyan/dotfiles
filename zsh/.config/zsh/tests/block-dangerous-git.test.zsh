#!/usr/bin/env zsh
# Pins claude/.claude/hooks/block-dangerous-git.py, the PreToolUse(Bash) hook
# that refuses destructive git commands in every Claude session. Drives the
# WORKING-TREE hook with synthetic PreToolUse payloads on stdin; the hook
# reads stdin and writes stderr only, so no sandbox is needed. Exit 2 = the
# hook refused the command (Claude Code shows the model the stderr text),
# exit 0 = passed through.
#
#   zsh ~/.config/zsh/tests/block-dangerous-git.test.zsh
#
# Policy: force-with-lease and remote ref deletes are allowed; --force, -f,
# +refspec and --mirror are refused in any argument order.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
HOOK="$DOT/claude/.claude/hooks/block-dangerous-git.py"
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

# --- unconditional overwrites: refused in any argument order ------------------
t 2 "git push --force"
t 2 "git push -f origin feat"
t 2 "git push origin main --force"
t 2 "git push -fu origin feat"
t 2 "git push -uf origin feat"
t 2 "git push origin +main"
t 2 "git push --mirror origin"
t 2 "git push origin --mirror"
t 2 "git push --mirr origin"
t 2 "git push --force-with-lease --force origin feat"
t 2 "git -C /tmp/p push --force"
t 2 "git -c push.default=current push origin feat --force"
t 2 "GIT_SSH_COMMAND='ssh -v' /usr/bin/git push origin feat -f"
t 2 "true && (git push --force)"
t 2 "cd /tmp/p; git push --force"

# --- lease-guarded force and remote deletes: allowed --------------------------
t 0 "git push --force-with-lease origin feat"
t 0 "git push -q --force-with-lease=feat:abc123 origin feat"
t 0 "git push --force-with-lease --force-if-includes origin feat"
t 0 "git push --delete origin feat"
t 0 "git push origin --delete feat"
t 0 "git push -d origin v1.0"
t 0 "git push origin :feat"
t 0 "git push -o ci.skip origin feat"

# --- work-destroying commands: never allowed ----------------------------------
t 2 "git reset --hard"
t 2 "git fetch && git reset --hard origin/main"
t 2 "git -C /tmp/p reset --hard"
t 2 "git reset origin/main --hard"
t 2 "git clean -fd"
t 2 "git clean -f"
t 2 "git clean -xdf"
t 2 "git -C /tmp/p clean -df"
t 2 "git checkout ."
t 2 "git checkout -- ."
t 2 "git checkout HEAD -- ."
t 2 "git restore ."
t 2 "git restore --staged --worktree ."
t 2 $'cat <<< hi\ngit reset --hard'
t 2 $'echo $((1<<2))\ngit reset --hard'
t 0 "git checkout .claude/settings.json"
t 0 "git restore .claude/settings.json"
t 0 "git checkout -- src/x"
t 0 "git restore --staged ."
t 0 "git clean -n"
t 0 "git reset --soft HEAD~1"

# --- force branch delete: gated, with a per-command bypass --------------------
t 2 "git branch -D feat"
t 2 "git fetch; git branch -D feat"
t 2 "git branch --delete --force feat"
t 2 "git branch -df feat"
t 0 "CLAUDE_ALLOW_BRANCH_DELETE=1 git branch -D feat"
t 2 "CLAUDE_ALLOW_BRANCH_DELETE=1 git branch -D a && git branch -D b"
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
t 0 $'git commit -m "line one\nmention git reset --hard in the body"'
t 0 "echo 'git branch -D feat'"
t 0 "git status  # then git push --force"
t 0 $'git commit -F - <<\'EOF\'\nwhy git clean -fd is blocked\nEOF'
t 0 $'git commit -m "$(cat <<\'EOF\'\nSay "hi"; git reset --hard\nEOF\n)"'

# --- the messages tell the model what to do ------------------------------------
msg=$(payload "git push origin main --force" | "$HOOK" 2>&1 >/dev/null) || true
if [[ "$msg" == *"git push origin main --force"* && "$msg" == *"NEVER bypassable"* && "$msg" == *"--force-with-lease"* ]]; then
  (( PASS++ )) || true; print -r -- "PASS force-push message names the command, says it cannot be bypassed, offers the lease"
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
