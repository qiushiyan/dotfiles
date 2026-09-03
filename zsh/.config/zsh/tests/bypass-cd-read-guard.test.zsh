#!/usr/bin/env zsh
# Pins claude/.claude/hooks/bypass-cd-read-guard.sh — the temporary workaround
# for Claude Code 2.1.259's "after a cd ... a Read() deny rule is configured;
# only you can approve" prompt reaching bypass-mode sessions. Drives the
# WORKING-TREE hook with synthetic PreToolUse payloads on stdin; the hook
# reads stdin and writes stderr only, so no sandbox is needed. Exit 2 = the
# hook refused the command (Claude Code shows the model the stderr text),
# exit 0 = passed through.
#
#   zsh ~/.config/zsh/tests/bypass-cd-read-guard.test.zsh
#
# Whether the hook is still NEEDED is a different question, answered by the
# retirement check in docs/bypass-cd-read-guard.md (it costs a real claude
# call, so it is not a case here).

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
HOOK="$DOT/claude/.claude/hooks/bypass-cd-read-guard.sh"
CWD="/tmp/proj"
typeset -i PASS=0 FAIL=0

[[ -x "$HOOK" ]] || { print -u2 "bypass-cd-read-guard.test: no executable hook at $HOOK"; exit 1 }

# t <want-exit> <permission_mode> <command>
t() {
  local want="$1" mode="$2" cmd="$3" rc err
  err=$(jq -cn --arg m "$mode" --arg c "$cmd" --arg d "$CWD" \
        '{permission_mode:$m,cwd:$d,tool_name:"Bash",tool_input:{command:$c}}' \
        | "$HOOK" 2>&1 >/dev/null); rc=$?
  if (( rc == want )); then
    (( PASS++ )) || true; print -r -- "PASS ($rc) ${cmd//$'\n'/⏎}"
  else
    (( FAIL++ )) || true; print -r -- "FAIL want=$want got=$rc  ${cmd//$'\n'/⏎}"
    print -r -- "$err" | sed 's/^/    /'
  fi
}

# --- refused: cd, then a guarded reader on a relative path -------------------
t 2 bypassPermissions "cd $CWD; grep -n -i 'spec' docs/loopy/standards.md | head -5"
t 2 bypassPermissions "cd $CWD/docs; grep -n spec loopy/standards.md"
t 2 bypassPermissions "cd $CWD && grep -n spec docs/a.md; grep -n spec docs/b.md"
t 2 bypassPermissions "cd $CWD && echo x; grep -n spec docs/a.md"
t 2 bypassPermissions "cd $CWD | cat; grep -n spec docs/a.md"
t 2 bypassPermissions "cd $CWD || exit 1; grep -n spec docs/a.md"
t 2 bypassPermissions $'cd '"$CWD"$'\ncat x; rg foo docs/'
t 2 bypassPermissions "cd $CWD; cp docs/a docs/b"
t 2 bypassPermissions "cd $CWD; git diff -- docs/loopy/standards.md"
t 2 bypassPermissions "cd $CWD; git log --oneline -3 -- .claude/settings.json"
t 2 bypassPermissions "cd $CWD; grep -e spec docs/loopy/standards.md"
t 2 bypassPermissions "cd $CWD; grep -n spec docs/f.md > out.txt"
t 2 bypassPermissions "cd $CWD; grep -n spec docs/f.md 2>/dev/null"

# --- passed through: nothing Claude Code's check would stop on ---------------
t 0 bypassPermissions "cd $CWD && grep -n spec docs/loopy/standards.md"
t 0 bypassPermissions "cd $CWD/docs && grep -n spec loopy/standards.md | head -5"
t 0 bypassPermissions "cd $CWD && git log --oneline -3 -- .claude/settings.json && cp docs/a docs/b"
t 0 bypassPermissions "cd $CWD; grep -n spec /abs/path/file.md"
t 0 bypassPermissions "grep -n spec docs/loopy/standards.md"
t 0 bypassPermissions "cd $CWD; git status; git log --oneline -3"
t 0 bypassPermissions "cd $CWD && ls docs && cat docs/x.md"
t 0 bypassPermissions "cd $CWD; git diff HEAD~1 --stat"

# --- passed through: the trigger text is inert (heredoc body, quoted string) --
t 0 bypassPermissions $'cat <<EOF\ncd somewhere; grep x y\nEOF'
t 0 bypassPermissions "echo 'cd here; grep a b'"
t 0 bypassPermissions "cd $CWD; git commit -m 'cd into it; grep later docs/x'"
t 0 bypassPermissions "P=$CWD; cd \$P; Q=\"cd \$P; grep -n spec docs/loopy/standards.md\"; run \"\$Q\""
t 0 bypassPermissions $'cd '"$CWD"$'; echo "a\nb; grep x docs/y"; ls'

# --- scope: prompted sessions are untouched; the git guard's job stays its own
t 0 default "cd $CWD; grep -n -i 'spec' docs/loopy/standards.md"
t 0 bypassPermissions "cd $CWD; git push --force"

# --- the message tells the model what to do ----------------------------------
msg=$(jq -cn --arg c "cd $CWD; grep -n spec docs/x.md" --arg d "$CWD" \
      '{permission_mode:"bypassPermissions",cwd:$d,tool_input:{command:$c}}' | "$HOOK" 2>&1 >/dev/null) || true
if [[ "$msg" == *"Drop the "*"cd"* && "$msg" == *"$CWD"* ]]; then
  (( PASS++ )) || true; print -r -- "PASS redundant-cd message names the cwd"
else
  (( FAIL++ )) || true; print -r -- "FAIL redundant-cd message"; print -r -- "$msg" | sed 's/^/    /'
fi
msg=$(jq -cn --arg c "cd $CWD/docs; grep -n spec x.md" --arg d "$CWD" \
      '{permission_mode:"bypassPermissions",cwd:$d,tool_input:{command:$c}}' | "$HOOK" 2>&1 >/dev/null) || true
if [[ "$msg" == *"&&"* && "$msg" == *"absolute paths"* ]]; then
  (( PASS++ )) || true; print -r -- "PASS other-dir message offers the && chain"
else
  (( FAIL++ )) || true; print -r -- "FAIL other-dir message"; print -r -- "$msg" | sed 's/^/    /'
fi

print -- "----"
print -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
