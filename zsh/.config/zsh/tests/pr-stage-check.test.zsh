#!/usr/bin/env zsh
# Pins claude/.claude/hooks/pr-stage-check.py, the PreToolUse(Bash) hook that
# stops the first `gh pr create` of a session that ran no review round or no
# verification, once, naming what is missing.
# Drives the WORKING-TREE hook with synthetic PreToolUse payloads on stdin.
# Exit 2 = the hook refused the call (Claude Code shows the model the stderr
# text), exit 0 with nothing printed = passed through.
#
#   zsh ~/.config/zsh/tests/pr-stage-check.test.zsh
#
# ISOLATION. The hook runs under `env -i` with HOME and XDG_STATE_HOME inside
# this suite's sandbox and a PATH of the sandbox's bin and /usr/bin:/bin, where
# `claude-steps` is a stub that prints a chosen document, sleeps, or is absent,
# so the real one never runs. The stub logs its arguments. A case that is
# silent because of what claude-steps said checks that the hook asked; a case
# that is silent before asking runs against a stub that would get it refused,
# and checks that the hook did not ask. Session ids carry this run's pid, and
# the last case asserts none of them reached the real state directory.

emulate -L zsh
setopt pipe_fail no_unset
zmodload zsh/datetime

DOT="${0:A:h:h:h:h:h}"
HOOK="$DOT/claude/.claude/hooks/pr-stage-check.py"
typeset -i PASS=0 FAIL=0 NSID=0 RC=0
typeset OUT="" SID=""

[[ -x "$HOOK" ]] || { print -u2 "pr-stage-check.test: no executable hook at $HOOK"; exit 1 }

REAL_HOME="$HOME"
REAL_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/claude-hooks/pr-stage-check"
BARE=/usr/bin:/bin
if env -i PATH="$BARE" /bin/sh -c 'command -v claude-steps' >/dev/null 2>&1; then
  print -u2 "pr-stage-check.test: $BARE holds a claude-steps, so no stub can stand in for it"; exit 1
fi
stale=("$REAL_STATE"/prsc-test-$$-*(N))
(( $#stale == 0 )) || { print -u2 "pr-stage-check.test: $REAL_STATE already holds this pid's test markers"; exit 1 }

# The sandbox holds the home, the state directory and the stub; the suite runs
# from it, and it is removed only once it is checked to be a temp directory.
SBX=$(mktemp -d "${TMPDIR:-/tmp}/pr-stage-check.XXXXXX") || exit 1
SBX=${SBX:A}
cleanup() {
  [[ -n "$SBX" && "$SBX" == /* && ( "$SBX" == /private/var/folders/* || "$SBX" == /private/tmp/* ) ]] \
    && rm -rf -- "$SBX"
}
trap cleanup EXIT
cd "$SBX" || exit 1

H="$SBX/home"; STATE="$SBX/state"; BIN="$SBX/bin"
MARKERS="$STATE/claude-hooks/pr-stage-check"
MAIN="$H/dev/planlab/main"; WT="$H/dev/.worktrees/main/feat-x"
mkdir -p "$BIN" "$MAIN" "$WT/src" "$H/dev/itell" "$H/dev/planlab/mainline" "$H/dev/.worktrees/dotfiles/feat-x"
ln -s "$WT" "$SBX/link"
typeset -a HOOK_ENV=(HOME="$H" XDG_STATE_HOME="$STATE" PATH="$BIN:$BARE")

# Every case runs under the PATH python3 and under macOS's /usr/bin/python3
# (3.9), the floor the hook must stay compatible with.
typeset -aU PYS=(${commands[python3]} /usr/bin/python3(N))

# What a refusal must tell the session, from the hook's PROJECTS table: the
# review skill's round when no review ran, the verify skill when no
# verification ran, the review snippet and its file (which starts both) only
# when neither ran, and the prompt check's snippet when that has not run
# either. The message's wording is the hook's own.
REVIEW='review-verify' FILE='~/dev/planlab/main/.tabtype.toml (a key in .tabtype.local.toml beside it wins)' PROMPTS='loopy-prompt-check'
VERIFY='planlab-verify' ROUND='full review'

pass() { (( PASS++ )) || true; print -r -- "PASS ${1//$'\n'/⏎}" }
fail() {
  (( FAIL++ )) || true; print -r -- "FAIL ${1//$'\n'/⏎}"
  [[ -z "${2-}" ]] || print -r -- "$2" | sed 's/^/    /'
}

# stub <sh>: a `claude-steps` that logs its arguments, then runs <sh>.
stub() {
  print -r -- "#!/bin/sh
echo \"\$*\" >> '$SBX/steps.args'
$1" > "$BIN/claude-steps"
  chmod +x "$BIN/claude-steps"
}
# view <status> [label ...]: the document `claude-steps show --json` prints for
# a session whose named labels have a step.
view() {
  local st="$1"; shift
  jq -cn --arg s "$st" '
    {id: "x", status: $s, unread_lines: 0, events: [], notes: [],
     labels: (["onboard", "consult", "spec", "build", "review", "verify", "docs", "pr-review", "prompts", "closeout"]
       | map(. as $n | {name: $n}
           + (if any($ARGS.positional[]; . == $n)
              then {latest: {at: "2026-11-10T12:00:00+08:00", kind: "snippet", key: "k"}} else {} end)))}' --args "$@"
}
# says <status> [label ...]: the stub answers with that view.
says() { view "$@" > "$SBX/steps.json"; stub "cat '$SBX/steps.json'" }
asked() { [[ -r "$SBX/steps.args" ]] && grep -qxF -- "show $1 --json" "$SBX/steps.args" }

payload() {
  jq -cn --arg s "$1" --arg d "$2" --arg c "$3" \
    '{session_id: $s, cwd: $d, hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}'
}
# hook <python> <payload>: OUT is everything the hook printed, RC its exit.
hook() { OUT=$(print -r -- "$2" | env -i $HOOK_ENV "$1" "$HOOK" 2>&1); RC=$? }
newsid() { SID="prsc-test-$$-$(( ++NSID ))" }

# refused <label> <cwd> <command> [ran ...]: exit 2 with a message that names
# what did not run, among the review (its snippet and file), the verification
# (its skill) and the prompt check (its snippet), and nothing that ran; a
# marker for the session that records what was missing; claude-steps asked.
refused() {
  local label="$1" cwd="$2" cmd="$3" py
  local -a ran=("${@[4,-1]}") missing=()
  (( ${ran[(Ie)review]} )) || missing+=(review)
  (( ${ran[(Ie)verify]} )) || missing+=(verify)
  local want=$(jq -cn '$ARGS.positional' --args $missing)
  for py in $PYS; do
    newsid; hook "$py" "$(payload "$SID" "$cwd" "$cmd")"
    if (( RC != 2 )); then fail "want refused, got rc=$RC [$py]  $label" "$OUT"
    elif (( ${missing[(Ie)review]} )) && [[ "$OUT" != *"\`$ROUND\`"* ]]; then fail "no review ran, and the review round is not named [$py]  $label" "$OUT"
    elif (( ! ${missing[(Ie)review]} )) && [[ "$OUT" == *"\`$ROUND\`"* ]]; then fail "names the review round though a review ran [$py]  $label" "$OUT"
    elif (( $#missing == 2 )) && [[ "$OUT" != *"\`$REVIEW\`"* || "$OUT" != *"$FILE"* ]]; then fail "neither ran, and the snippet that starts both or its file is not named [$py]  $label" "$OUT"
    elif (( $#missing == 1 )) && [[ "$OUT" == *"\`$REVIEW\`"* ]]; then fail "one ran, yet the snippet that runs both is named [$py]  $label" "$OUT"
    elif (( ${missing[(Ie)verify]} )) && [[ "$OUT" != *"$VERIFY"* ]]; then fail "no verification ran, and the verify skill is not named [$py]  $label" "$OUT"
    elif (( ! ${missing[(Ie)verify]} )) && [[ "$OUT" == *"$VERIFY"* ]]; then fail "names the verify skill though a verification ran [$py]  $label" "$OUT"
    elif (( ${ran[(Ie)prompts]} )) && [[ "$OUT" == *"$PROMPTS"* ]]; then fail "names the prompt check though one ran [$py]  $label" "$OUT"
    elif (( ! ${ran[(Ie)prompts]} )) && [[ "$OUT" != *"$PROMPTS"* ]]; then fail "refused without naming the prompt check [$py]  $label" "$OUT"
    elif [[ ! -e "$MARKERS/$SID" ]]; then fail "refused without a marker [$py]  $label"
    elif ! jq -e --argjson w "$want" '.missing == $w' "$MARKERS/$SID" >/dev/null 2>&1; then fail "the marker does not record $want as missing [$py]  $label" "$(cat "$MARKERS/$SID")"
    elif ! asked "$SID"; then fail "refused without asking claude-steps [$py]  $label"
    else pass "(refused) $label"; fi
  done
}
# silent <asked|unasked> <label> <cwd> <command>: exit 0, nothing printed, no
# marker, and claude-steps asked about the session or left alone.
silent() {
  local want="$1" label="$2" cwd="$3" cmd="$4" py got
  for py in $PYS; do
    newsid; hook "$py" "$(payload "$SID" "$cwd" "$cmd")"
    if asked "$SID"; then got=asked; else got=unasked; fi
    if (( RC != 0 )) || [[ -n "$OUT" ]]; then fail "want silent, got rc=$RC [$py]  $label" "$OUT"
    elif [[ -e "$MARKERS/$SID" ]]; then fail "silent, but left a marker [$py]  $label"
    elif [[ "$got" != "$want" ]]; then fail "silent, but claude-steps was $got [$py]  $label"
    else pass "(silent, $want) $label"; fi
  done
}
# quiet <label> <payload>: exit 0 and nothing printed, for a payload the
# helpers above cannot build; claude-steps is not asked, no marker appears.
quiet() {
  local label="$1" json="$2" py before after
  for py in $PYS; do
    before="$(cat "$SBX/steps.args" 2>/dev/null | wc -l) $(ls -A "$STATE/claude-hooks" "$MARKERS" 2>/dev/null | wc -l)"
    hook "$py" "$json"
    after="$(cat "$SBX/steps.args" 2>/dev/null | wc -l) $(ls -A "$STATE/claude-hooks" "$MARKERS" 2>/dev/null | wc -l)"
    if (( RC != 0 )) || [[ -n "$OUT" ]]; then fail "want silent, got rc=$RC [$py]  $label" "$OUT"
    elif [[ "$before" != "$after" ]]; then fail "silent, but asked or left a marker [$py]  $label"
    else pass "(silent, unasked) $label"; fi
  done
}

# --- no review, no verification: refused, and the message names what to run ----
says ok
refused "main checkout, nothing ran: review, verification and prompt check named" "$MAIN" "gh pr create --fill"
refused "a worktree: all three named" "$WT" "gh pr create --fill"
refused "below a worktree's root" "$WT/src" "gh pr create --fill"
refused "a cwd spelled through a symlink" "$SBX/link" "gh pr create --fill"
says ok onboard spec build prompts
refused "main checkout, a prompt check ran: review and verification" "$MAIN" "gh pr create --fill" prompts
refused "a worktree, a prompt check ran: review and verification" "$WT" "gh pr create --fill" prompts

# --- one of the two ran: refused, naming the other alone --------------------------
says ok review
refused "a review ran: verification and prompt check named" "$WT" "gh pr create --fill" review
says ok build review prompts
refused "a review and a prompt check ran: verification alone" "$WT" "gh pr create --fill" review prompts
says ok verify
refused "a verification ran: review and prompt check named" "$WT" "gh pr create --fill" verify
says ok verify prompts
refused "a verification and a prompt check ran: review alone" "$MAIN" "gh pr create --fill" verify prompts

# A label whose latest step is only a prompt naming its skill ran nothing.
stub "echo '{\"status\":\"ok\",\"labels\":[{\"name\":\"review\",\"latest\":{\"at\":\"x\",\"kind\":\"skill\"}},{\"name\":\"verify\",\"latest\":{\"at\":\"x\",\"kind\":\"mention\"}},{\"name\":\"prompts\",\"latest\":{\"at\":\"x\",\"kind\":\"snippet\"}}]}'"
refused "a verification only mentioned: verification named" "$WT" "gh pr create --fill" review prompts
stub "echo '{\"status\":\"ok\",\"labels\":[{\"name\":\"review\",\"latest\":{\"at\":\"x\",\"kind\":\"mention\"}},{\"name\":\"verify\",\"latest\":{\"at\":\"x\",\"kind\":\"mention\"}},{\"name\":\"prompts\",\"latest\":{\"at\":\"x\",\"kind\":\"mention\"}}]}'"
refused "all three only mentioned: all three named" "$MAIN" "gh pr create --fill"

# --- once per session ------------------------------------------------------------
says ok
for py in $PYS; do
  newsid
  hook "$py" "$(payload "$SID" "$WT" "gh pr create --fill")"; r1=$RC
  hook "$py" "$(payload "$SID" "$WT" "gh pr create --fill")"; r2=$RC; o2="$OUT"
  hook "$py" "$(payload "$SID" "$MAIN" "gh pr create --draft --title later")"; r3=$RC; o3="$OUT"
  newsid
  hook "$py" "$(payload "$SID" "$WT" "gh pr create --fill")"; r4=$RC
  if (( r1 == 2 && r2 == 0 && r3 == 0 && r4 == 2 )) && [[ -z "$o2$o3" ]]; then
    pass "(2 0 0 2) refused once, the session's later calls silent, another session refused again"
  else
    fail "once per session: got $r1 $r2 $r3 $r4 [$py]" "$o2$o3"
  fi
done

# --- a review step and a verify step: silent --------------------------------------
says ok review verify
silent asked "main checkout, a review and a verification" "$MAIN" "gh pr create --fill"
silent asked "a worktree, a review and a verification" "$WT" "gh pr create --fill"
says ok build review verify prompts
silent asked "a review, a verification and a prompt check" "$WT/src" "gh pr create --fill"

# --- gh pr create wherever the shell runs it -------------------------------------
says ok
runs() { refused "$1" "$WT" "$1" }
runs "gh pr create"
runs "gh pr create --title 'Fix the parser' --body 'what and why' --draft"
runs "cd $WT && gh pr create --fill"
runs "git push -u origin HEAD && gh pr create --fill"
runs "git push -u origin HEAD; gh pr create --fill"
runs "GH_PAGER= gh pr create --fill"
runs "env GH_TOKEN=x gh pr create --fill"
runs "timeout 60 gh pr create --fill"
runs "command gh pr create --fill"
runs "/opt/homebrew/bin/gh pr create --fill"
runs 'url=$(gh pr create --fill)'
runs 'echo "opened $(gh pr create --fill)"'
runs "if git push; then gh pr create --fill; fi"
runs "gh pr -R acme/planlab create --fill"
runs "gh pr create -R acme/planlab --fill"
runs "gh pr new --fill"
runs $'gh pr create --title "Fix the parser" --body "$(cat <<\'EOF\'\n## Summary\nwhy\nEOF\n)"'
runs $'cat <<EOF\n$(gh pr create --fill)\nEOF'

# --- other gh commands, and text that only mentions it ---------------------------
inert() { silent unasked "$1" "$WT" "$1" }
inert "gh pr view"
inert "gh pr view --json url,state"
inert "gh pr edit 12 --title 'create the index'"
inert "gh pr list --search create"
inert "gh pr checks --watch"
inert "gh pr comment 12 --body 'gh pr create'"
inert "gh issue create --title 'gh pr create fails'"
inert "gh repo create acme/pr"
inert "gh pr create --help"
inert "gh pr create --dry-run --fill"
inert "git pr create"
inert "echo 'gh pr create'"
inert 'echo "then gh pr create --fill"'
inert 'echo "\$(gh pr create --fill)"'
inert "git commit -m 'next: gh pr create'"
inert "git status  # then gh pr create --fill"
inert $'cat <<\'EOF\'\ngh pr create --fill\nEOF'
inert $'cat <<\'EOF\'\n$(gh pr create --fill)\nEOF'
inert $'git commit -F - <<"EOF"\nopen it with gh pr create\nEOF'
inert $'cat <<EOF\nnext: gh pr create --fill\nEOF'

# --- outside the table's projects ------------------------------------------------
outside() { silent unasked "outside: ${1/#$SBX/…}" "$1" "gh pr create --fill" }
outside "$H/dev/itell"
outside "$H/dev/.worktrees/dotfiles/feat-x"
outside "$H/dev/planlab/mainline"
outside "$H/dev/planlab"
outside "$H/dev/.worktrees"
outside "$H"
outside "/tmp"
# `~` in the table is the running user's home: under the sandbox HOME, the
# real home's checkout is some other directory.
silent unasked "outside: the real home's checkout under another HOME" "$REAL_HOME/dev/planlab/main" "gh pr create --fill"

# --- whatever it cannot establish passes -----------------------------------------
for st in partial unreadable missing; do
  says "$st"
  silent asked "status $st" "$MAIN" "gh pr create --fill"
done
stub "echo 'claude-steps: this is not JSON'"
silent asked "an answer that is not JSON" "$MAIN" "gh pr create --fill"
stub "echo '{\"status\":\"ok\"}'"
silent asked "JSON without labels" "$MAIN" "gh pr create --fill"
stub "echo '[]'"
silent asked "JSON that is not an object" "$MAIN" "gh pr create --fill"
stub "echo '{\"status\":\"ok\",\"labels\":[{\"name\":\"build\"},{\"name\":\"prompts\"}]}'"
silent asked "labels without a review" "$MAIN" "gh pr create --fill"
stub "echo '{\"status\":\"ok\",\"labels\":[{\"name\":\"review\",\"latest\":{\"at\":\"x\"}},{\"name\":\"prompts\"}]}'"
silent asked "a review step and no verify label: the verification is unknown" "$MAIN" "gh pr create --fill"
stub "echo '{\"status\":\"ok\",\"labels\":[{\"name\":\"review\"},\"prompts\"]}'"
silent asked "a label it cannot read after the review: no refusal, and none remembered" "$MAIN" "gh pr create --fill"
stub "echo 'claude-steps: error: no session matches' >&2; exit 1"
silent asked "claude-steps fails" "$MAIN" "gh pr create --fill"
says ok
stub "cat '$SBX/steps.json'; exit 1"
silent asked "claude-steps fails after printing a view that would refuse" "$MAIN" "gh pr create --fill"

stub "exec sleep 30"
for py in $PYS; do
  newsid; t0=$EPOCHREALTIME
  hook "$py" "$(payload "$SID" "$MAIN" "gh pr create --fill")"
  dt=$(( EPOCHREALTIME - t0 ))
  if (( RC == 0 && dt >= 4 && dt < 20 )) && [[ -z "$OUT" && ! -e "$MARKERS/$SID" ]] && asked "$SID"; then
    pass "(silent, asked) a claude-steps slower than the limit, given up on after $(printf '%.1f' $dt)s"
  else
    fail "slow claude-steps: rc=$RC after $(printf '%.1f' $dt)s [$py]" "$OUT"
  fi
done

rm -f "$BIN/claude-steps"
silent unasked "no claude-steps on PATH" "$MAIN" "gh pr create --fill"

says ok
quiet "no session id" "$(jq -cn --arg d "$MAIN" '{cwd: $d, tool_name: "Bash", tool_input: {command: "gh pr create --fill"}}')"
quiet "an empty session id" "$(payload "" "$MAIN" "gh pr create --fill")"
quiet "a session id that is a path" "$(payload "../prsc-test-$$-escape" "$MAIN" "gh pr create --fill")"
quiet "a session id that is an option" "$(payload "--help" "$MAIN" "gh pr create --fill")"
quiet "no cwd" "$(jq -cn --arg s "prsc-test-$$-nocwd" '{session_id: $s, tool_name: "Bash", tool_input: {command: "gh pr create --fill"}}')"
quiet "a relative cwd" "$(payload "prsc-test-$$-rel" "home/dev/planlab/main" "gh pr create --fill")"
quiet "no command" "$(jq -cn --arg s "prsc-test-$$-nocmd" --arg d "$MAIN" '{session_id: $s, cwd: $d, tool_name: "Write", tool_input: {file_path: "/tmp/x"}}')"
quiet "unreadable input" "not json"

# --- where it remembers ------------------------------------------------------------
# A marker it cannot write: the refusal could not be remembered, so none is made.
print -r -- "a file where the state directory would go" > "$SBX/afile"
HOOK_ENV=(HOME="$H" XDG_STATE_HOME="$SBX/afile" PATH="$BIN:$BARE")
silent asked "a state directory that cannot be made" "$MAIN" "gh pr create --fill"
# Without XDG_STATE_HOME, or with it empty, the markers go under ~/.local/state.
MARKERS="$H/.local/state/claude-hooks/pr-stage-check"
HOOK_ENV=(HOME="$H" PATH="$BIN:$BARE")
refused "XDG_STATE_HOME unset: the marker is under ~/.local/state" "$MAIN" "gh pr create --fill"
HOOK_ENV=(HOME="$H" XDG_STATE_HOME= PATH="$BIN:$BARE")
refused "XDG_STATE_HOME empty: the same" "$MAIN" "gh pr create --fill"

# --- the labels it reads ---------------------------------------------------------
# The hook knows a step ran only through the session board's labels, so each
# project's verify skill must be under the real config's `verify` label and
# its review key under `review` and `verify`: a name missing there refuses
# every session that ran it.
labels_out=$(python3 - "$HOOK" "$DOT/claude-steps/.config/claude-steps/config.toml" <<'PY' 2>&1
import importlib.util, sys, tomllib
spec = importlib.util.spec_from_file_location("hook", sys.argv[1]); hook = importlib.util.module_from_spec(spec); spec.loader.exec_module(hook)
labels = {l["name"]: l for l in tomllib.load(open(sys.argv[2], "rb"))["label"]}
for p in hook.PROJECTS:
    if p["verify"] not in labels["verify"].get("skills", []): print(f'{p["name"]}: {p["verify"]} is not a verify skill')
    for name in ("review", "verify"):
        if p["review"] not in labels[name].get("snippets", []): print(f'{p["name"]}: {p["review"]} is not a {name} snippet')
PY
)
if [[ $? == 0 && -z "$labels_out" ]]; then pass "the board's labels hold every name the hook prints"
else fail "the board's labels and the hook's names disagree" "$labels_out"; fi

# --- the real state directory ------------------------------------------------------
leaked=("$REAL_STATE"/prsc-test-*$$*(N) "$REAL_STATE:h"/prsc-test-*$$*(N))
if (( $#leaked == 0 )); then pass "no session of this run left a marker in $REAL_STATE"
else fail "markers reached the real state directory" "${(F)leaked}"; fi

print -- "----"
print -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
