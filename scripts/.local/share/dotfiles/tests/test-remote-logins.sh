#!/usr/bin/env bash
# test-remote-logins.sh — remote-logins' contract: which accounts it signs in,
# which Chrome profile each page opens in, the code reaching the other
# machine's `headroom login finish`, Codex's device sign-in, and the Keychain
# hand-off.
#
# Usage: bash test-remote-logins.sh [R1 R4 ...]     (run it from a scratch directory)
#
# ISOLATION. `ssh` and `open` are stubs on PATH: ssh plays the other machine's
# headroom from canned answers and logs each command and what it was fed,
# open logs what it would have opened. Chrome's profiles are a fixture Local
# State. Nothing reaches a real machine or browser.

set -uo pipefail

TOOL="$(cd "$(dirname "$0")/../../../bin" && pwd)/remote-logins"
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/remote-logins-test.XXXXXX")
cd "$SANDBOX" || exit 1
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/Local State" <<'EOF'
{"profile": {"info_cache": {
  "Profile 1": {"name": "Work", "user_name": "a@x.com"},
  "Profile 2": {"name": "b", "user_name": ""},
  "Profile 3": {"name": "zzz", "user_name": ""},
  "Profile 4": {"name": "cq", "user_name": ""}
}}}
EOF

# ssh stub: the other machine's headroom. a@x.com is due for renewal, b@x.com
# is not, c@x.com has no Chrome profile here, k@x.com logs in through the
# Keychain. The Codex primary is "cq", cq@x.com.
cat > "$SANDBOX/bin/ssh" <<'EOF'
#!/bin/sh
host=$1; shift; cmd=$*
printf '%s\t%s\n' "$host" "$cmd" >> "$SSH_LOG"
url='https://claude.com/cai/oauth/authorize?state=s1&redirect_uri=https%3A%2F%2Fplatform.claude.com%2Fcb'
case $cmd in
  *"login --all --dry-run --json"*)
    echo '{"accounts":[{"account":"a@x.com","renew":true},{"account":"b@x.com","renew":false}]}' ;;
  *"login --dry-run --json"*)
    echo '{"accounts":[{"account":"a@x.com","renew":true},{"account":"b@x.com","renew":false}]}' ;;
  *"login start 'k@x.com'"*)
    echo '{"state":null,"reason":"keychain_unreadable","problem":"the login Keychain is closed"}' ;;
  *"login start '"*)
    acct=$(printf '%s' "$cmd" | sed "s/.*login start '\([^']*\)'.*/\1/")
    printf '{"state":"awaiting_code","email":"%s","url":"%s"}\n' "$acct" "$url" ;;
  *"login finish '"*)
    printf 'code\t%s\n' "$(cat)" >> "$SSH_LOG"
    echo '{"state":"renewed","login_ends_at":"2026-12-01T00:00:00Z"}' ;;
  *"--json --vendor codex"*)
    echo '{"accounts":[{"vendor":"codex","name":"cq","email":"cq@x.com"}]}' ;;
  *"launch --vendor codex"*)
    echo "Open https://auth.openai.com/codex/device and enter ABCD-1234"
    echo "Successfully logged in" ;;
  *"--compact"*) echo "board" ;;
  *) echo "stub ssh: unexpected: $cmd" >&2; exit 99 ;;
esac
EOF
cat > "$SANDBOX/bin/open" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$OPEN_LOG"
EOF
chmod +x "$SANDBOX/bin/ssh" "$SANDBOX/bin/open"
export PATH="$SANDBOX/bin:$PATH" REMOTE_LOGINS_LOCAL_STATE="$SANDBOX/Local State"
export SSH_LOG="$SANDBOX/ssh.log" OPEN_LOG="$SANDBOX/open.log"

fresh() { : > "$SSH_LOG"; : > "$OPEN_LOG"; }
run() { out=$(printf '%s\n' "${CODES:-the-code#s1}" | "$TOOL" "$@" 2>&1); rc=$?; }
starts() { grep -o "login start '[^']*'" "$SSH_LOG" | sed "s/login start //; s/'//g" | tr '\n' ' ' | sed 's/ $//'; }

CASE=R1; if want; then
    fresh; run mini2
    ok "R1 bare signs in only the accounts due for renewal" "a@x.com" "$(starts)"
    ok "R1 the page opens in the profile signed in as the email" 1 "$(grep -c -- '--profile-directory=Profile 1 https://claude.com/' "$OPEN_LOG")"
    ok "R1 the pasted code reaches finish on that host" "1" "$(grep -c $'^code\tthe-code#s1$' "$SSH_LOG")"
    ok "R1 every command goes to the named host" "" "$(grep -v $'^mini2\t' "$SSH_LOG" | grep -v $'^code\t')"
    ok "R1 exit 0 when every account signed in" 0 "$rc"
fi

CASE=R2; if want; then
    fresh; run mini2 b@x.com
    ok "R2 a named account is signed in even when not due" "b@x.com" "$(starts)"
    ok "R2 an unsigned profile named after the local part takes it" 1 "$(grep -c -- '--profile-directory=Profile 2 ' "$OPEN_LOG")"
fi

CASE=R3; if want; then
    fresh; run mini2 c@x.com
    ok "R3 no matching profile: nothing opens" "" "$(cat "$OPEN_LOG")"
    ok "R3 no matching profile: the URL is printed to open by hand" 1 "$(grep -c 'no Chrome profile here matches c@x.com' <<<"$out")"
fi

CASE=R4; if want; then
    fresh; run mini k@x.com
    ok "R4 a Keychain login is handed to one interactive command" 1 \
       "$(grep -cF "ssh -t mini 'security unlock-keychain && ~/.local/bin/headroom login k@x.com'" <<<"$out")"
    ok "R4 and the run exits 1" 1 "$rc"
    ok "R4 no code is sent for it" 0 "$(grep -c '^code' "$SSH_LOG")"
fi

CASE=R5; if want; then
    fresh; run mini2 codex:cq
    ok "R5 Codex's device page opens in the profile for its email" 1 "$(grep -c -- '--profile-directory=Profile 4 https://auth.openai.com/codex/device' "$OPEN_LOG")"
    ok "R5 Codex signs in through headroom on that host" 1 "$(grep -c "launch --vendor codex --account 'cq' -- login --device-auth" "$SSH_LOG")"
    ok "R5 the device code is shown" 1 "$(grep -c 'ABCD-1234' <<<"$out")"
fi

CASE=R6; if want; then
    fresh; CODES=$'c1#s1\nc2#s1' run mini2 --all
    ok "R6 --all takes every Claude Code account" "a@x.com b@x.com" "$(starts)"
    ok "R6 --all takes every Codex account" 1 "$(grep -c "launch --vendor codex --account 'cq'" "$SSH_LOG")"
fi

CASE=R7; if want; then
    "$TOOL" >/dev/null 2>&1; ok "R7 no host is a usage error" 2 $?
    ok "R7 --help prints the usage" 1 "$("$TOOL" --help | grep -c '^Usage: remote-logins <host>')"
fi

echo "remote-logins: $PASS passed, $FAIL failed${FAILED:+ —$FAILED}"
[ "$FAIL" -eq 0 ]
