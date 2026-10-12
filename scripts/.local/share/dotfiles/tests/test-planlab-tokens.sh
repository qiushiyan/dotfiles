#!/usr/bin/env bash
# test-planlab-tokens.sh — planlab-tokens' contract: the newest token of
# each label decides whether a reminder is due; a due token, a rejected
# local token, or a long silence sends one DM from the app's bot (or your
# own DM through `slack` without it); rotate-eval proves the clipboard
# token before it writes, and changes only the EVAL_SUBMIT_TOKEN line.
#
# Usage: bash test-planlab-tokens.sh [P1 R2 ...]
#
# ISOLATION. curl, slack, aws and pbpaste are stubs on PATH that log every
# call and answer from sandbox files, and HOME is a temporary directory, so
# nothing reaches PlanLab, Slack or AWS. P8 asserts no secret was ever on a
# command line; Z1 asserts the real state, env and Slack files are untouched.

set -uo pipefail

TOOL="$(cd "$(dirname "$0")/../../../bin" && pwd)/planlab-tokens"
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/planlab-tokens-test.XXXXXX")
cd "$SANDBOX" || exit 1
real_before() { ls -la "$HOME/.local/state/planlab-tokens" "$HOME/.planlab/.env" "$HOME/.config/slack" 2>/dev/null | shasum; }
REAL_HOME=$HOME
REAL_BEFORE=$(real_before)
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
has() { printf '%s' "$2" | grep -qF -- "$1" && echo yes || echo no; }  # has <needle> <haystack>

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

LOCAL_SECRET=localSecretAAAA1111
EVAL_SECRET=evalSecretBBBB2222
NOW=$(date +%s)
iso() { date -u -r $(( NOW + $1 )) +%Y-%m-%dT%H:%M:%S.000Z; }  # iso <seconds from now>
DAY=86400

mkdir -p "$SANDBOX/bin"
# Stub curl: the bearer arrives on stdin (-H @-) and is logged apart from
# argv. The token list answers 200 to an accepted secret, else 401, unless
# STUB_LIST_CODE forces a status; Slack answers auth.test and records the
# chat.postMessage body.
cat > "$SANDBOX/bin/curl" <<'EOF'
#!/bin/bash
printf 'curl %s\n' "$*" >> "$STUB_ARGV"
hdr=$(cat); printf '%s\n' "$hdr" >> "$STUB_STDIN"
bearer=$(printf '%s' "$hdr" | sed -n 's/^Authorization: Bearer //p')
url=${!#}; data=""
while [ $# -gt 0 ]; do [ "$1" = --data-binary ] && data=$2; shift; done
case $url in
  */api/admin/backstage-tokens)
    if [ -n "${STUB_LIST_CODE:-}" ]; then printf '\n%s' "$STUB_LIST_CODE"; [ "$STUB_LIST_CODE" = 000 ] && exit 7; exit 0; fi
    case " $STUB_ACCEPT " in *" $bearer "*) cat "$STUB_LIST"; printf '\n200' ;; *) printf 'unauthorized\n401' ;; esac ;;
  */auth.test)
    if [ "$bearer" = xoxp-test ]; then echo '{"ok":true,"user_id":"UTEST"}'; else echo '{"ok":false,"error":"invalid_auth"}'; fi ;;
  */chat.postMessage)
    printf '%s' "$data" > "$STUB_POSTED"
    if [ "$bearer" = xoxb-test ]; then echo '{"ok":true}'; else echo '{"ok":false,"error":"not_authed"}'; fi ;;
  *) echo "stub curl: unexpected $url" >&2; exit 99 ;;
esac
EOF
cat > "$SANDBOX/bin/slack" <<'EOF'
#!/bin/sh
printf 'slack %s\n' "$*" >> "$STUB_ARGV"
case $1 in
  whoami) echo "planlab: qiushi (UTEST) at PlanLab · planlab.example · bot token registered" ;;
  post) cat > "$STUB_SLACK_POSTED" ;;
  *) echo "stub slack: unexpected: $*" >&2; exit 99 ;;
esac
EOF
cat > "$SANDBOX/bin/pbpaste" <<'EOF'
#!/bin/sh
cat "$STUB_CLIPBOARD"
EOF
# Stub aws: the secret lives in $STUB_SECRET; a put replaces it with stdin.
cat > "$SANDBOX/bin/aws" <<'EOF'
#!/bin/sh
printf 'aws %s profile=%s\n' "$*" "${AWS_PROFILE:-}" >> "$STUB_ARGV"
case "$1 $2" in
  "sts get-caller-identity") [ -z "${STUB_AWS_NOAUTH:-}" ] || { echo "Token has expired" >&2; exit 255; }; echo '{}' ;;
  "secretsmanager get-secret-value") cat "$STUB_SECRET" ;;
  "secretsmanager put-secret-value") cat > "$STUB_SECRET"; echo v-new ;;
  *) echo "stub aws: unexpected: $*" >&2; exit 99 ;;
esac
EOF
chmod +x "$SANDBOX/bin/"*
export PATH="$SANDBOX/bin:$PATH"

# fresh: a new HOME with the env file and Slack tokens, empty logs, and the
# list answer built from "label:createdOffset:expiresOffset" arguments.
fresh() {
    rm -rf "$SANDBOX/home" "$SANDBOX"/*.log "$SANDBOX"/posted*; mkdir -p "$SANDBOX/home/.planlab" "$SANDBOX/home/.config/slack"
    export HOME="$SANDBOX/home"
    export STUB_ARGV="$SANDBOX/argv.log" STUB_STDIN="$SANDBOX/stdin.log" STUB_POSTED="$SANDBOX/posted.json"
    export STUB_SLACK_POSTED="$SANDBOX/posted-slack.txt" STUB_LIST="$SANDBOX/list.json"
    export STUB_CLIPBOARD="$SANDBOX/clipboard" STUB_SECRET="$SANDBOX/secret" STUB_ACCEPT="$LOCAL_SECRET $EVAL_SECRET"
    : > "$STUB_ARGV"; : > "$STUB_STDIN"
    unset STUB_LIST_CODE STUB_AWS_NOAUTH XDG_STATE_HOME SLACK_CONFIG_DIR PLANLAB_ENV_FILE PLANLAB_TOKENS_WARN_DAYS AWS_PROFILE
    echo "PLANLAB_BACKSTAGE_TOKEN=www.planlab.example:$LOCAL_SECRET" > "$HOME/.planlab/.env"
    printf 'planlab=xoxp-test\nplanlab-bot=xoxb-test\n' > "$HOME/.config/slack/tokens.env"
    local spec label c e rows=""
    for spec in "$@"; do
        IFS=: read -r label c e <<<"$spec"
        rows+="${rows:+,}{\"label\":\"$label\",\"createdAt\":\"$(iso "$c")\",\"expiresAt\":\"$(iso "$e")\"}"
    done
    echo "{\"tokens\":[$rows]}" > "$STUB_LIST"
}
posted_text() { jq -r .text "$STUB_POSTED" 2>/dev/null; }
calls() { grep -c "$1" "$STUB_ARGV"; }

CASE=P1; if want; then
    fresh "dev:-$DAY:$((20*DAY))" "EVAL_SUBMIT_TOKEN:-$DAY:$((25*DAY - DAY/2))"
    out=$("$TOOL" check --notify 2>&1); rc=$?
    ok "P1 exit 0" 0 "$rc"
    ok "P1 lists dev" yes "$(has 'dev' "$out")"
    ok "P1 lists EVAL_SUBMIT_TOKEN with its distance" yes "$(has 'in 24 days' "$out")"
    ok "P1 says none due" yes "$(has 'none due within 7 days' "$out")"
    ok "P1 sends nothing" 0 "$(calls 'chat.postMessage')"
    ok "P1 asks the token's own host" 1 "$(calls 'https://www.planlab.example/api/admin/backstage-tokens')"
    ok "P1 sends only the secret as the bearer" yes "$(has "Authorization: Bearer $LOCAL_SECRET" "$(cat "$STUB_STDIN")")"
fi

CASE=P2; if want; then
    # dev's older token has lapsed but a newer one replaced it; the eval's is due.
    fresh "dev:$((-40*DAY)):$((-10*DAY))" "dev:-$DAY:$((29*DAY))" "EVAL_SUBMIT_TOKEN:$((-27*DAY)):$((3*DAY - DAY/2))"
    out=$("$TOOL" check --notify 2>&1); rc=$?
    text=$(posted_text)
    ok "P2 exit 0" 0 "$rc"
    ok "P2 one DM" 1 "$(calls 'chat.postMessage')"
    ok "P2 DM goes to the user auth.test named" UTEST "$(jq -r .channel "$STUB_POSTED")"
    ok "P2 auth.test with the user token" yes "$(has 'Authorization: Bearer xoxp-test' "$(cat "$STUB_STDIN")")"
    ok "P2 posts with the bot token" yes "$(has 'Authorization: Bearer xoxb-test' "$(cat "$STUB_STDIN")")"
    ok "P2 names the due token" yes "$(has '*EVAL_SUBMIT_TOKEN* expires' "$text")"
    ok "P2 says how far off" yes "$(has 'in 2 days' "$text")"
    ok "P2 says what to do with it" yes "$(has 'planlab-tokens rotate-eval' "$text")"
    ok "P2 links the mint page" yes "$(has 'https://www.planlab.example/backstage?tab=apiTokens' "$text")"
    ok "P2 a replaced token is not due" no "$(has '*dev*' "$text")"
fi

CASE=P3; if want; then
    fresh "dev:$((-31*DAY)):$((-2*DAY - DAY/2))"
    "$TOOL" check --notify >/dev/null 2>&1; rc=$?
    text=$(posted_text)
    ok "P3 exit 0" 0 "$rc"
    ok "P3 an unreplaced lapsed token is due" yes "$(has '*dev* expired' "$text")"
    ok "P3 says how long ago" yes "$(has '2 days ago' "$text")"
    ok "P3 says where it goes" yes "$(has 'PLANLAB_BACKSTAGE_TOKEN in `~/.planlab/.env`' "$text")"
    fresh "dev:-$DAY:$((10*DAY))"; export PLANLAB_TOKENS_WARN_DAYS=14
    "$TOOL" check --notify >/dev/null 2>&1
    ok "P3 PLANLAB_TOKENS_WARN_DAYS widens the window" 1 "$(calls 'chat.postMessage')"
fi

CASE=P4; if want; then
    fresh "dev:-$DAY:$((20*DAY))"; export STUB_ACCEPT="$EVAL_SECRET"
    out=$("$TOOL" check 2>&1); rc=$?
    ok "P4 check without --notify exits 0" 0 "$rc"
    ok "P4 prints the rejection" yes "$(has 'PLANLAB_BACKSTAGE_TOKEN was rejected' "$out")"
    ok "P4 without --notify sends nothing" 0 "$(calls 'chat.postMessage')"
    "$TOOL" check --notify >/dev/null 2>&1
    ok "P4 --notify DMs the rejection" yes "$(has '*PLANLAB_BACKSTAGE_TOKEN* in `~/.planlab/.env` was rejected' "$(posted_text)")"
fi

CASE=P5; if want; then
    fresh "dev:-$DAY:$((20*DAY))"; export STUB_LIST_CODE=000
    state="$HOME/.local/state/planlab-tokens/last-answer"
    out=$("$TOOL" check --notify 2>&1); rc=$?
    ok "P5 no answer exits 0" 0 "$rc"
    ok "P5 says so" yes "$(has 'HTTP 000' "$out")"
    ok "P5 the first silence sends nothing" 0 "$(calls 'chat.postMessage')"
    echo $(( NOW - 4*DAY )) > "$state"
    "$TOOL" check --notify >/dev/null 2>&1
    ok "P5 three days of silence sends one DM" 1 "$(calls 'chat.postMessage')"
    ok "P5 the DM says the expiries are unknown" yes "$(has 'expiries are unknown' "$(posted_text)")"
    unset STUB_LIST_CODE
    "$TOOL" check --notify >/dev/null 2>&1
    ok "P5 an answer restarts the clock" yes "$([ $(( $(cat "$state") >= NOW )) -eq 1 ] && echo yes || echo no)"
    ok "P5 and sends nothing more" 1 "$(calls 'chat.postMessage')"
fi

CASE=P6; if want; then
    fresh "dev:-$DAY:$((2*DAY))"
    printf 'planlab=xoxp-test\n' > "$HOME/.config/slack/tokens.env"
    out=$("$TOOL" check --notify 2>&1); rc=$?
    ok "P6 exit 0" 0 "$rc"
    ok "P6 no bot post" 0 "$(calls 'chat.postMessage')"
    ok "P6 your own DM through slack" 1 "$(calls 'slack post UTEST -w planlab --format mrkdwn --text-file - --send')"
    ok "P6 the text goes on stdin" yes "$(has '*dev* expires' "$(cat "$STUB_SLACK_POSTED")")"
    ok "P6 says it will not notify" yes "$(has 'does not notify' "$out")"
fi

CASE=P7; if want; then
    fresh "dev:-$DAY:$((2*DAY))"
    printf 'planlab=xoxp-wrong\nplanlab-bot=xoxb-test\n' > "$HOME/.config/slack/tokens.env"
    "$TOOL" check --notify >/dev/null 2>&1; ok "P7 a failed DM exits 1" 1 $?
    rm "$HOME/.planlab/.env"
    out=$("$TOOL" check 2>&1); rc=$?
    ok "P7 no local token exits 1" 1 "$rc"
    ok "P7 names the file" yes "$(has 'no PLANLAB_BACKSTAGE_TOKEN in ~/.planlab/.env' "$out")"
    "$TOOL" check --bogus >/dev/null 2>&1; ok "P7 an unknown flag exits 2" 2 $?
    "$TOOL" rotate-eval extra >/dev/null 2>&1; ok "P7 rotate-eval takes no argument" 2 $?
    "$TOOL" >/dev/null 2>&1; ok "P7 no verb exits 2" 2 $?
fi

SECRET_BODY=$'DATABASE_URL=postgres://x\nEVAL_SUBMIT_TOKEN=www.planlab.example:oldSecret\nOPENROUTER_API_KEY=sk-or\nPEM<<EOF\nline\nEOF'

CASE=R1; if want; then
    fresh "EVAL_SUBMIT_TOKEN:-60:$((30*DAY))"
    printf '%s' "$SECRET_BODY" > "$STUB_SECRET"
    printf '  www.planlab.example:%s\n' "$EVAL_SECRET" > "$STUB_CLIPBOARD"
    out=$("$TOOL" rotate-eval 2>&1); rc=$?
    ok "R1 exit 0" 0 "$rc"
    ok "R1 the line holds the new token" "EVAL_SUBMIT_TOKEN=www.planlab.example:$EVAL_SECRET" "$(grep '^EVAL_SUBMIT_TOKEN=' "$STUB_SECRET")"
    ok "R1 every other line is byte for byte" "$(printf '%s' "$SECRET_BODY" | grep -v '^EVAL_SUBMIT_TOKEN=')" "$(grep -v '^EVAL_SUBMIT_TOKEN=' "$STUB_SECRET")"
    ok "R1 the breakglass profile wrote it" 1 "$(grep -c 'put-secret-value --secret-id app --secret-string file:///dev/stdin .*profile=planlab-prod-breakglass' "$STUB_ARGV")"
    ok "R1 reports the version and the token's end" yes "$(has "ends …2222 (version v-new)" "$out")"
    "$TOOL" rotate-eval >/dev/null 2>&1; rc=$?
    ok "R1 again: already in place, exit 0" 0 "$rc"
    ok "R1 again: no second write" 1 "$(calls 'put-secret-value')"
fi

CASE=R2; if want; then
    fresh
    printf '%s' "$SECRET_BODY" > "$STUB_SECRET"
    echo "www.planlab.example:notAToken" > "$STUB_CLIPBOARD"
    out=$("$TOOL" rotate-eval 2>&1); rc=$?
    ok "R2 a rejected clipboard token exits 1" 1 "$rc"
    ok "R2 says nothing was written" yes "$(has 'rejected the token on the clipboard (HTTP 401); nothing was written' "$out")"
    ok "R2 never reaches AWS" 0 "$(calls '^aws')"
fi

CASE=R3; if want; then
    fresh
    printf '%s' "$SECRET_BODY" > "$STUB_SECRET"
    : > "$STUB_CLIPBOARD"
    "$TOOL" rotate-eval >/dev/null 2>&1; ok "R3 an empty clipboard exits 1" 1 $?
    printf 'a\nb\n' > "$STUB_CLIPBOARD"
    "$TOOL" rotate-eval >/dev/null 2>&1; ok "R3 two lines exit 1" 1 $?
    ok "R3 neither asks anyone" 0 "$(wc -l < "$STUB_ARGV" | tr -d ' ')"
fi

CASE=R4; if want; then
    fresh
    printf 'DATABASE_URL=postgres://x\n' > "$STUB_SECRET"
    echo "www.planlab.example:$EVAL_SECRET" > "$STUB_CLIPBOARD"
    out=$("$TOOL" rotate-eval 2>&1); rc=$?
    ok "R4 a secret without the line exits 1" 1 "$rc"
    ok "R4 writes nothing" 0 "$(calls 'put-secret-value')"
    : > "$STUB_SECRET"
    "$TOOL" rotate-eval >/dev/null 2>&1; ok "R4 an empty read exits 1" 1 $?
    ok "R4 still writes nothing" 0 "$(calls 'put-secret-value')"
    printf '%s' "$SECRET_BODY" > "$STUB_SECRET"; export STUB_AWS_NOAUTH=1
    : > "$STUB_ARGV"
    out=$("$TOOL" rotate-eval 2>&1); rc=$?
    ok "R4 no AWS session exits 1" 1 "$rc"
    ok "R4 says how to sign in" yes "$(has 'aws sso login --profile planlab-prod-breakglass' "$out")"
    ok "R4 never reads the secret" 0 "$(calls 'get-secret-value')"
fi

CASE=P8; if want; then
    # Every case above logged its argv here; run one more of each kind.
    fresh "dev:-$DAY:$((2*DAY))"
    "$TOOL" check --notify >/dev/null 2>&1
    printf '%s' "$SECRET_BODY" > "$STUB_SECRET"
    echo "www.planlab.example:$EVAL_SECRET" > "$STUB_CLIPBOARD"
    "$TOOL" rotate-eval >/dev/null 2>&1
    leaked=$(grep -cE "$LOCAL_SECRET|$EVAL_SECRET|xoxp-test|xoxb-test|oldSecret" "$STUB_ARGV")
    ok "P8 no secret on any command line" 0 "$leaked"
fi

CASE=Z1; if want; then
    HOME_SAVED=$HOME; export HOME=$REAL_HOME
    ok "Z1 real state, env and Slack files untouched" "$REAL_BEFORE" "$(real_before)"
    export HOME=$HOME_SAVED
fi

echo "planlab-tokens: $PASS passed, $FAIL failed${FAILED:+ —$FAILED}"
[ "$FAIL" -eq 0 ]
