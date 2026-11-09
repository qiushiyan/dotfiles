#!/usr/bin/env zsh
# Pins claude/.claude/hooks/answer-rm-prompts.py, the PermissionRequest(Bash)
# hook that approves Claude Code's dangerous-rm prompt when every removal in
# the command stays strictly inside a temp directory. Drives the WORKING-TREE
# hook with synthetic PermissionRequest payloads on stdin. The hook prints an
# allow decision or nothing; it writes only its log, which every case points
# into this suite's sandbox.
#
#   zsh ~/.config/zsh/tests/answer-rm-prompts.test.zsh

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
HOOK="$DOT/claude/.claude/hooks/answer-rm-prompts.py"
typeset -i PASS=0 FAIL=0

[[ -x "$HOOK" ]] || { print -u2 "answer-rm-prompts.test: no executable hook at $HOOK"; exit 1 }

# The sandbox holds the log and the symlink fixtures; the suite runs from it,
# and it is removed only once it is checked to be a temp directory.
SBX=$(mktemp -d "${TMPDIR:-/tmp}/answer-rm-prompts.XXXXXX") || exit 1
SBX=${SBX:A}
cleanup() {
  [[ -n "$SBX" && "$SBX" == /* && ( "$SBX" == /private/var/folders/* || "$SBX" == /private/tmp/* ) ]] \
    && rm -rf -- "$SBX"
}
trap cleanup EXIT
cd "$SBX" || exit 1
export CLAUDE_RM_PROMPTS_LOG="$SBX/log.jsonl"
mkdir -p "$SBX/real" && ln -s "$HOME" "$SBX/to-home"

T=/tmp/answer-rm-prompts-cases   # targets are only read, never created
U=$(id -u)

payload() { jq -cn --arg c "$1" --argjson s "${2:-[]}" '{tool_name:"Bash",tool_input:{command:$c},permission_suggestions:$s,cwd:"/tmp"}' }

typeset -aU PYS=(${commands[python3]} /usr/bin/python3(N))

# check <approve|defer> <payload> <label>
check() {
  local want="$1" json="$2" label="$3" out got py
  for py in $PYS; do
    out=$(print -r -- "$json" | "$py" "$HOOK" 2>&1)
    if [[ "$out" == *'"behavior": "allow"'* ]]; then got=approve
    elif [[ -z "$out" ]]; then got=defer
    else got="output: $out"; fi
    if [[ "$got" == "$want" ]]; then
      (( PASS++ )) || true; print -r -- "PASS ($want) ${label//$'\n'/⏎}"
    else
      (( FAIL++ )) || true; print -r -- "FAIL want=$want got=$got [$py]  ${label//$'\n'/⏎}"
    fi
  done
}
t() { check "$1" "$(payload "$2")" "$2" }

# --- no removal: what Claude Code would have run had it parsed the command ----
t approve "python3 - <<'EOF'
p='src/universal-index/search-corpus.ts'
s=open(p).read()
a='''  const typeFilter = sourceTypes?.length ? (params.push([...sourceTypes]), \`AND d.\"sourceType\" = ANY(\$\${params.length}::text[])\`) : '';'''
assert a in s; s=s.replace(a,'x',1)
open(p,'w').write(s)
EOF
sed -n 780,830p src/universal-index/search.test.ts"
t approve "ls -la; git status"
t approve "cat <<EOF
\$(rm -rf $T/inside-an-unquoted-heredoc)
EOF"

# --- removals inside a temp directory ------------------------------------------
t approve "X=$T; rm -rf \$X/junk"
t approve "S=$T/scratch; du -sh \$S/*; rm -rf \$S/mut \$S/*.bak \$S/g-*.json"
t approve "S=$T; rm -rf \"\${S:?}\"/build \"\${S}/out\""
t approve "rm -f /tmp/t1-fixups.md"
t approve "rm -rf /private/tmp/x/{a,b}"
t approve "cd $T && rm -rf build node_modules"
t approve "export W=$T/w; rm -rf -- \"\$W/a\""
t approve "rm -rf \$TMPDIR/answer-rm-prompts-case"
t approve "bash -c 'rm -rf $T/y'"
t approve "D=$T/d; trap 'rm -rf \"\$D\"' EXIT; echo hi"
t approve "rm -rf /tmp/claude-$U/some-project/some-session"
t approve "rm $SBX/to-home"

# --- the prompt stays -----------------------------------------------------------
t defer "Q=$T/q; L=$T/l; rm -rf \"\$L/\$(cat \$Q/lane.thread)\""
t defer "rm -rf \$(cat files.txt)"
t defer "rm -rf \`cat files.txt\`"
t defer "rm -rf $T/\`cat name\`"
t defer "rm -f -- \"\$failed_root/\$sha\""
t defer "rm -rf \$S/*"
t defer "S=/tmp; rm -rf \$S/*"
t defer "rm -rf /tmp"
t defer "rm -rf /tmp/"
t defer "rm -rf /tmp/../Users/someone"
t defer "rm -rf /tmp/claude-$U/some-project"
t defer "rm -rf /tmp/claude-$U/*/x"
t defer "rm -rf ~/dev/scratch"
t defer "rm -rf build"
t defer "(cd $T && true); rm -rf build"
t defer "S=$T; S=\$(pwd); rm -rf \$S/y"
t defer "S=$T; for S in / /etc; do rm -rf \$S/y; done"
t defer "S=$T; read S < f; rm -rf \$S/y"
t defer "S=$T; unset S; rm -rf \$S/y"
t defer "S=$T; S+=/../..; rm -rf \$S/y"
t defer "S=$T rm -rf \$S/y"
t defer "S=$T; echo \"\$(rm -rf \$S/y)\""
t defer "X=$T; bash -c \"rm -rf \$X/y\""
t defer "D=$T/d; trap 'rm -rf \"\$D\"' EXIT; D=\$(pwd)"
t defer "find $T -name '*.o' -delete"
t defer "ls | xargs rm -f"
t defer "eval \"rm -rf \$X\""
t defer "case \$x in a) rm -rf $T/a;; esac"
t defer "rm -rf $SBX/to-home/"
t defer "rm -rf $SBX/to-home/Documents"

# --- which prompts it answers ----------------------------------------------------
check defer "$(payload "rm -rf $T/x" '[{"type":"addRules","rules":[{"toolName":"Bash","ruleContent":"rm"}],"behavior":"allow","destination":"localSettings"}]')" "a prompt that offers a rule (not a safety check)"
check defer "$(jq -cn --arg c "rm -rf $T/x" '{tool_name:"Bash",tool_input:{command:$c}}')" "no permission_suggestions field"
check defer '{"tool_name":"Write","tool_input":{"file_path":"/tmp/x"},"permission_suggestions":[]}' "not Bash"
check defer 'not json' "unreadable input"

# --- the log ----------------------------------------------------------------------
if [[ -s "$SBX/log.jsonl" ]] && jq -e 'select(.approved == false) | .why' "$SBX/log.jsonl" >/dev/null; then
  (( PASS++ )) || true; print "PASS log names why a prompt stayed"
else
  (( FAIL++ )) || true; print "FAIL log missing or without reasons"
fi
: > "$SBX/log.jsonl"
CLAUDE_RM_PROMPTS_LOG= check approve "$(payload "rm -f /tmp/t1-fixups.md")" "an empty CLAUDE_RM_PROMPTS_LOG writes no log"
if [[ -s "$SBX/log.jsonl" ]]; then (( FAIL++ )) || true; print "FAIL the empty lever still logged"
else (( PASS++ )) || true; print "PASS the empty lever logs nothing"; fi

print "\n$PASS passed, $FAIL failed"
(( FAIL == 0 ))
