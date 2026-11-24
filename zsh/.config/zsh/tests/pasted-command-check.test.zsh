#!/usr/bin/env zsh
# Pins claude/.claude/hooks/pasted-command-check.py, the UserPromptSubmit
# hook that stops a message whose slash command was pasted and collapsed, so
# Claude Code does not send it to the model as text. Drives the WORKING-TREE
# hook with synthetic payloads on stdin, shaped as Claude Code 2.1.331 gave
# them to a probe hook. The skills and commands it looks for are fixtures
# under a throwaway HOME and project; the hook writes nothing.
#
#   zsh ~/.config/zsh/tests/pasted-command-check.test.zsh

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
HOOK="$DOT/claude/.claude/hooks/pasted-command-check.py"
typeset -i PASS=0 FAIL=0

[[ -x "$HOOK" ]] || { print -u2 "pasted-command-check.test: no executable hook at $HOOK"; exit 1 }

SBX=$(mktemp -d "${TMPDIR:-/tmp}/pasted-command-check.XXXXXX") || exit 1
SBX=${SBX:A}
cleanup() {
  [[ -n "$SBX" && "$SBX" == /* && ( "$SBX" == /private/var/folders/* || "$SBX" == /private/tmp/* ) ]] \
    && rm -rf -- "$SBX"
}
trap cleanup EXIT
cd "$SBX" || exit 1

# Fixtures: one skill or command in each place a session finds them.
H="$SBX/home" P="$SBX/project" C="$SBX/account"
mkdir -p "$H/.claude/skills/strategic-review" "$H/.agents/skills/agent-only" \
  "$P/.claude/skills/pl-verify" "$P/.claude/commands" "$P/sub" "$C/skills/account-only"
touch "$H/.claude/skills/strategic-review/SKILL.md" "$H/.agents/skills/agent-only/SKILL.md" \
  "$P/.claude/skills/pl-verify/SKILL.md" "$P/.claude/commands/ship-it.md" \
  "$C/skills/account-only/SKILL.md"
git -C "$P" init -q || exit 1

tag() { print -rn -- $'\n\n<pasted_content id="d61f">\n'"$1"$'\n</pasted_content id="d61f">\n' }
payload() { jq -cn --arg p "$1" --arg c "${2:-$P}" '{hook_event_name:"UserPromptSubmit",prompt:$p,cwd:$c}' }

typeset -aU PYS=(${commands[python3]} /usr/bin/python3(N))

# check <block|pass> <prompt> <label> [cwd]
check() {
  local want="$1" prompt="$2" label="$3" cwd="${4:-$P}" out got py
  for py in $PYS; do
    out=$(payload "$prompt" "$cwd" | env -u CLAUDE_CONFIG_DIR HOME="$H" CLAUDE_CONFIG_DIR="$C" "$py" "$HOOK" 2>&1)
    if [[ "$out" == *'"decision": "block"'* ]]; then got=block
    elif [[ -z "$out" ]]; then got=pass
    else got="output: $out"; fi
    if [[ "$got" == "$want" ]]; then
      (( PASS++ )) || true; print -r -- "PASS ($want) $label"
    else
      (( FAIL++ )) || true; print -r -- "FAIL want=$want got=$got [$py]  $label"
    fi
  done
}

BRIEF=$'Build session: 9b18\n\nOne generated commit moves 1,079 files.'

# --- a collapsed paste that opens with a command this session has: stopped ---
check block "$(tag "/strategic-review 12384"$'\n'"$BRIEF")" "personal skill under ~/.claude"
check block "$(tag "/agent-only x"$'\n'"$BRIEF")" "skill under ~/.agents/skills"
check block "$(tag "/account-only"$'\n'"$BRIEF")" "skill in the account's config dir, no arguments"
check block "$(tag "/pl-verify 12384"$'\n'"$BRIEF")" "project skill, session at the checkout root"
check block "$(tag "/pl-verify 12384"$'\n'"$BRIEF")" "project skill, session in a subfolder" "$P/sub"
check block "$(tag "/ship-it now"$'\n'"$BRIEF")" "project command file"
check block "$(tag "/goal ship it"$'\n'"$BRIEF")" "built-in command that takes words"
check block "$(tag "/some-plugin:review 1"$'\n'"$BRIEF")" "plugin command"
check block $'Pasted text:\n/strategic-review 12384\n'"$BRIEF" "untagged paste form"

# --- anything else: passed --------------------------------------------------
check pass $'/strategic-review 12384\n'"$BRIEF" "expanded paste or typed command: Claude Code runs it"
check pass "please look at this$(tag "/strategic-review 12384"$'\n'"$BRIEF")" "words typed before the paste"
check pass "$(tag "/tmp"$'\n'"/var"$'\n'"/usr")" "a listing whose first line is a path"
check pass "$(tag "/Users/me/notes.md is where"$'\n'"$BRIEF")" "a path with a slash after its first word"
check pass "$(tag "/nonexistent-skill 1"$'\n'"$BRIEF")" "a name this session has no command for"
check pass "$(tag "Agreeing with the general direction"$'\n'"$BRIEF")" "a paste of prose"
check pass "just a typed message" "no paste at all"

# --- a broken payload lets the message through --------------------------------
for py in $PYS; do
  out=$(print -r -- 'not json' | "$py" "$HOOK" 2>&1)
  if [[ -z "$out" ]]; then (( PASS++ )) || true; print -r -- "PASS (pass) unreadable payload"
  else (( FAIL++ )) || true; print -r -- "FAIL unreadable payload printed: $out [$py]"; fi
done

print -r -- "pasted-command-check: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
