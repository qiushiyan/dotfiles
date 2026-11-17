#!/usr/bin/env bash
# test-aws-login.sh — aws-login's contract: a profile that already works is
# left signed in; otherwise, or with --renew, sign out, sign in, verify,
# stamp; the device-code flow on the mini; --status reads the stamp.
#
# Usage: bash test-aws-login.sh [A1 A4 ...]
#
# ISOLATION. `aws` is a stub on PATH that records every call and answers from
# environment knobs (STUB_LOGIN_RC, STUB_STS_RC) and a marker file standing in
# for the live session ($STUB_SESSION: sso login creates it, sso logout
# removes it, sts answers only while it exists), and HOME is a temporary
# directory, so no real token is touched and the stamp lands in the sandbox.
# A8 asserts the real state directory was never written.

set -uo pipefail

LOGIN="$(cd "$(dirname "$0")/../../../bin" && pwd)/aws-login"
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/aws-login-test.XXXXXX")
REAL_STATE="$HOME/.local/state/aws-login"
real_state_before() { ls -la "$REAL_STATE" 2>/dev/null | shasum; }
REAL_STATE_BEFORE=$(real_state_before)
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/aws" <<'EOF'
#!/bin/sh
# Stub aws: log the call, answer like the real CLI for the subcommands
# aws-login uses.
printf '%s\n' "$*" >> "$STUB_LOG"
case "$1 $2" in
  "configure list-profiles")
    printf 'default\nplanlab-dev\nplanlab-prod\nplanlab-legacy\n'
    # Profiles after the match outlast a reader that stops at it.
    if [ -n "${STUB_PROFILES_PAD:-}" ]; then seq 1 200000 | sed 's/^/pad-/'; fi ;;
  "configure get")  # sso_session for the sso profiles; legacy has none
    case "$*" in *planlab-legacy*) exit 1 ;; *) echo planlab ;; esac ;;
  "sso logout") rm -f "$STUB_SESSION"; echo "Successfully signed out of all SSO profiles." ;;
  "sso login")
    [ "${STUB_LOGIN_RC:-0}" -eq 0 ] || exit "$STUB_LOGIN_RC"
    : > "$STUB_SESSION" ;;
  "sts get-caller-identity")
    [ "${STUB_STS_RC:-0}" -eq 0 ] || exit "$STUB_STS_RC"
    [ -e "$STUB_SESSION" ] || { echo "Error when retrieving token from sso: Token has expired and refresh failed" >&2; exit 255; }
    echo "arn:aws:sts::000000000000:assumed-role/Stub/user" ;;
  *) echo "stub aws: unexpected: $*" >&2; exit 99 ;;
esac
EOF
chmod +x "$SANDBOX/bin/aws"
export PATH="$SANDBOX/bin:$PATH"

# fresh: a new HOME and call log, signed out; the machine marker is set per
# case, and signed_in starts a live session.
fresh() {
    rm -rf "$SANDBOX/home"; mkdir -p "$SANDBOX/home/.config"
    export HOME="$SANDBOX/home" STUB_LOG="$SANDBOX/calls" STUB_SESSION="$SANDBOX/session"
    : > "$STUB_LOG"; rm -f "$STUB_SESSION"
    unset STUB_LOGIN_RC STUB_STS_RC STUB_PROFILES_PAD XDG_STATE_HOME
}
signed_in() { : > "$STUB_SESSION"; }
calls() { cat "$STUB_LOG"; }
stamp() { cat "$HOME/.local/state/aws-login/$1" 2>/dev/null; }

CASE=A1; if want; then
    fresh
    out=$("$LOGIN" 2>&1); rc=$?
    ok "A1 exit 0" 0 "$rc"
    ok "A1 signed out: check, logout, login, verify in order" \
       "$(printf 'sts get-caller-identity --profile planlab-prod --output text --query Arn\nsso logout\nsso login --profile planlab-prod\nsts get-caller-identity --profile planlab-prod --output text --query Arn')" \
       "$(calls | grep -v '^configure')"
    ok "A1 stamp keyed by sso-session" 1 "$( [ -n "$(stamp planlab)" ] && echo 1 || echo 0 )"
    ok "A1 stamp is an epoch" 1 "$( [[ $(stamp planlab) =~ ^[0-9]{10}$ ]] && echo 1 || echo 0 )"
    ok "A1 reports identity" 1 "$(printf '%s' "$out" | grep -c 'identity:   arn:aws:sts')"
fi

CASE=A2; if want; then
    fresh
    "$LOGIN" planlab-dev >/dev/null 2>&1
    ok "A2 profile argument reaches check, login and verify" 3 "$(calls | grep -v '^configure' | grep -c -- '--profile planlab-dev')"
    ok "A2 legacy profile stamps under its own name" 1 "$( fresh; "$LOGIN" planlab-legacy >/dev/null 2>&1; [ -n "$(stamp planlab-legacy)" ] && echo 1 || echo 0 )"
fi

CASE=A3; if want; then
    fresh
    "$LOGIN" >/dev/null 2>&1
    ok "A3 laptop: browser flow" 0 "$(calls | grep -c -- '--use-device-code')"
    fresh; echo mini > "$HOME/.config/machine"
    "$LOGIN" >/dev/null 2>&1
    ok "A3 mini marker: device-code flow" "sso login --profile planlab-prod --use-device-code" "$(calls | grep '^sso login')"
    fresh
    "$LOGIN" --use-device-code --no-browser >/dev/null 2>&1
    ok "A3 flags pass through" "sso login --profile planlab-prod --use-device-code --no-browser" "$(calls | grep '^sso login')"
fi

CASE=A4; if want; then
    fresh; export STUB_LOGIN_RC=1
    out=$("$LOGIN" 2>&1); rc=$?
    ok "A4 login failure exits 1" 1 "$rc"
    ok "A4 no verify after failed login" "sso login --profile planlab-prod" "$(calls | grep -v '^configure' | tail -1)"
    ok "A4 no stamp after failed login" "" "$(stamp planlab)"
    ok "A4 says the old session is gone" 1 "$(printf '%s' "$out" | grep -c 'old session is already ended')"
fi

CASE=A5; if want; then
    fresh; export STUB_STS_RC=254
    "$LOGIN" >/dev/null 2>&1; rc=$?
    ok "A5 verify failure exits 1" 1 "$rc"
    ok "A5 no stamp without credentials" "" "$(stamp planlab)"
fi

CASE=A6; if want; then
    fresh; signed_in
    out=$("$LOGIN" --status 2>&1); rc=$?
    ok "A6 status without stamp: signed in unknown, exit 0" "0 1" "$rc $(printf '%s' "$out" | grep -c 'signed in:  unknown')"
    ok "A6 status signs nothing in or out" 0 "$(calls | grep -c '^sso')"
    "$LOGIN" --renew >/dev/null 2>&1
    out=$("$LOGIN" --status 2>&1); rc=$?
    ok "A6 status after login: exit 0, shows session end" "0 1" "$rc $(printf '%s' "$out" | grep -c '^ends:       ~.*8-hour session')"
    export STUB_STS_RC=254
    out=$("$LOGIN" --status 2>&1); rc=$?
    ok "A6 status without credentials exits 1" "1 1" "$rc $(printf '%s' "$out" | grep -c 'credentials: none')"
fi

CASE=A7; if want; then
    fresh
    out=$("$LOGIN" no-such-profile 2>&1); rc=$?
    ok "A7 unknown profile exits 2 and lists profiles" "2 1" "$rc $(printf '%s' "$out" | grep -c '  planlab-prod')"
    ok "A7 unknown profile signs nothing out" 0 "$(calls | grep -c '^sso')"
    "$LOGIN" --bogus >/dev/null 2>&1; ok "A7 unknown option exits 2" 2 "$?"
    "$LOGIN" a b >/dev/null 2>&1; ok "A7 two profiles exits 2" 2 "$?"
fi

CASE=A9; if want; then
    fresh; signed_in; export STUB_PROFILES_PAD=1
    out=$("$LOGIN" --status 2>&1); rc=$?
    ok "A9 profile found ahead of a long list" "0 0" "$rc $(printf '%s' "$out" | grep -c 'no profile')"
fi

CASE=A10; if want; then
    fresh
    "$LOGIN" >/dev/null 2>&1
    started=$(stamp planlab)
    : > "$STUB_LOG"
    out=$("$LOGIN" planlab-dev 2>&1); rc=$?
    ok "A10 live session: another profile exits 0" 0 "$rc"
    ok "A10 live session: nothing signed out or in" 0 "$(calls | grep -c '^sso')"
    ok "A10 live session: says so, with identity" "1 1" "$(printf '%s' "$out" | grep -c 'already signed in; nothing signed out') $(printf '%s' "$out" | grep -c 'identity:   arn:aws:sts')"
    ok "A10 live session: session start kept" "$started" "$(stamp planlab)"
    ok "A10 live session: reports the session end and --renew" "1 1" "$(printf '%s' "$out" | grep -c '^ends:       ~') $(printf '%s' "$out" | grep -c 'aws-login planlab-dev --renew')"
    ok "A10 live session: the named profile still works afterwards" 1 "$( [ -e "$STUB_SESSION" ] && echo 1 || echo 0 )"
fi

CASE=A11; if want; then
    fresh; signed_in
    out=$("$LOGIN" --renew 2>&1); rc=$?
    ok "A11 --renew on a live session: logout, login, verify" \
       "$(printf 'sso logout\nsso login --profile planlab-prod\nsts get-caller-identity --profile planlab-prod --output text --query Arn')" \
       "$(calls | grep -v '^configure')"
    ok "A11 --renew stamps a new start" "0 1" "$rc $( [[ $(stamp planlab) =~ ^[0-9]{10}$ ]] && echo 1 || echo 0 )"
fi

CASE=A8; if want; then
    ok "A8 real state directory untouched" "$REAL_STATE_BEFORE" "$(real_state_before)"
fi

printf '\n%d passed, %d failed%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
