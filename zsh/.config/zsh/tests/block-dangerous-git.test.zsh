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
# +refspec and --mirror are refused in any argument order. A git command is
# judged wherever the shell would run it (behind wrappers, inside command
# substitutions and expanding heredocs) and nowhere else (quoted text, quoted
# heredoc bodies, comments).

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
HOOK="$DOT/claude/.claude/hooks/block-dangerous-git.py"
typeset -i PASS=0 FAIL=0

[[ -x "$HOOK" ]] || { print -u2 "block-dangerous-git.test: no executable hook at $HOOK"; exit 1 }

payload() { jq -cn --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' }

# Every case runs under the PATH python3 and under macOS's /usr/bin/python3
# (3.9), the floor the hook must stay compatible with.
typeset -aU PYS=(${commands[python3]} /usr/bin/python3(N))

# t <want-exit> <command>
t() {
  local want="$1" cmd="$2" rc err py
  for py in $PYS; do
    err=$(payload "$cmd" | "$py" "$HOOK" 2>&1 >/dev/null); rc=$?
    if (( rc == want )); then
      (( PASS++ )) || true; print -r -- "PASS ($rc) ${cmd//$'\n'/⏎}"
    else
      (( FAIL++ )) || true; print -r -- "FAIL want=$want got=$rc [$py]  ${cmd//$'\n'/⏎}"
      print -r -- "$err" | sed 's/^/    /'
    fi
  done
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

# --- whole-tree discards: forced checkouts and whole-tree pathspecs -----------
t 2 "git checkout -f"
t 2 "git checkout --force"
t 2 "git checkout -f main"
t 2 "git checkout -qf main"
t 2 "git checkout --forc main"
t 2 "git switch --discard-changes main"
t 2 "git switch -f main"
t 2 "git switch --force main"
t 2 "git restore :"
t 2 "git restore :/"
t 2 "git restore ':(top)'"
t 2 "git restore ':(top).'"
t 2 "git restore ':(top,glob)*'"
t 2 "git restore '*'"
t 2 "git restore ./"
t 2 "git restore .."
t 2 "git checkout -- :/"
t 2 "git checkout HEAD -- ':(top)'"
t 2 "git restore -W :/"
t 0 "git restore --staged :/"
t 0 "git restore -S ':(top)'"
t 0 "git restore ':(top)src/x'"
t 0 "git restore ':!vendor'"
t 0 "git checkout -f -- src/x"
t 0 "git checkout main"
t 0 "git checkout -b feat"
t 0 "git checkout ':/fix the parser'"
t 0 "git switch -c feat"
t 0 "git switch main"

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

# --- executable git wherever the shell runs it --------------------------------
t 2 'echo "$(git push origin main --force)"'
t 2 'result="$(git reset --hard)"'
t 2 'x=$(git reset --hard)'
t 2 'echo "`git reset --hard`"'
t 2 'echo "${x:-$(git checkout -- .)}"'
t 2 'echo "$(echo "$(git clean -fd)")"'
t 2 $'echo "$(cat <<EOF\n$(git reset --hard)\nEOF\n)"'
t 2 $'cat <<EOF\n$(git checkout -- .)\nEOF'
t 2 $'cat <<EOF\n`git reset --hard`\nEOF'
t 2 $'cat <<-EOF\n\t$(git reset --hard)\n\tEOF'
t 2 $'cat <<EOF; echo done\nkeep\nEOF\ngit reset --hard'
t 2 'diff <(git reset --hard) x'
t 2 "env -u GIT_DIR git reset --hard"
t 2 "env -i git reset --hard"
t 2 "env -i PATH=/usr/bin git reset --hard"
t 2 "env --unset GIT_DIR git reset --hard"
t 2 "env - git reset --hard"
t 2 "sudo -u x git reset --hard"
t 2 "sudo -E -u x env -u A git push --force"
t 2 "nice -n 5 git reset --hard"
t 2 "nice -n5 git reset --hard"
t 2 "command -p git reset --hard"
t 2 "exec -a g git reset --hard"
t 2 "exec git reset --hard"
t 2 "timeout 5 git push --force"
t 2 "timeout -s KILL 5 git push --force"
t 2 "nohup git clean -fd"
t 2 "time -p git reset --hard"
t 2 "noglob git checkout ."
t 2 "stdbuf -o L git reset --hard"
t 2 "caffeinate -t 60 git reset --hard"
t 2 "if true; then git reset --hard; fi"
t 2 "env CLAUDE_ALLOW_BRANCH_DELETE=0 git branch -D feat"
t 0 "env CLAUDE_ALLOW_BRANCH_DELETE=1 git branch -D feat"

# --- inert text: a dangerous phrase that is not executed ----------------------
t 0 "git commit -m 'never git push --force here'"
t 0 "git commit -m \"undo with git reset --hard\""
t 0 $'git commit -m "line one\nmention git reset --hard in the body"'
t 0 "echo 'git branch -D feat'"
t 0 "git status  # then git push --force"
t 0 $'git commit -F - <<\'EOF\'\nwhy git clean -fd is blocked\nEOF'
t 0 $'git commit -m "$(cat <<\'EOF\'\nSay "hi"; git reset --hard\nEOF\n)"'
t 0 $'cat <<\'EOF\'\n$(git reset --hard)\nEOF'
t 0 $'cat <<"EOF"\n`git reset --hard`\nEOF'
t 0 $'cat <<\\EOF\n$(git reset --hard)\nEOF'
t 0 $'cat <<E"OF"\n$(git reset --hard)\nEOF'
t 0 $'cat <<EOF\nmention git reset --hard and \\$(git clean -fd)\nEOF'
t 0 "echo '\$(git reset --hard)'"
t 0 'echo "\$(git reset --hard)"'
t 0 'git commit -m "fix: $(date) after git reset --hard"'
t 0 'echo "$(git status) never git push --force"'

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
