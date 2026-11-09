#!/usr/bin/env bash
# test-planlab-login-all.sh — planlab-login-all's contract: every machine
# twin.toml lists logs in at once, this one locally and the others over ssh
# by the manifest's alias in a login shell; every approval link is printed
# before any outcome; login options after -- reach each login intact; a
# machine that does not answer, or a login that ends unapproved, is named
# and makes the exit 1 while the others still finish; a named machine
# narrows the run, and an unknown one starts nothing.
#
# Usage: bash test-planlab-login-all.sh [L1 L2 ...]
#
# ISOLATION. ssh, zsh and planlab are stubs on PATH: ssh runs the remote
# command here through the stub zsh, and planlab prints a login transcript
# without reaching PlanLab. HOME is a temporary directory holding a copy of
# the working tree's twin.toml; Z1 asserts the real ~/.planlab/.env is
# untouched.

set -uo pipefail

TOOL="$(cd "$(dirname "$0")/../../../bin" && pwd)/planlab-login-all"
REPO="$(cd "$(dirname "$0")/../../../../.." && pwd)"
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/planlab-login-all-test.XXXXXX")
cd "$SANDBOX" || exit 1
real_before() { ls -la "$HOME/.planlab/.env" 2>/dev/null | shasum; }
REAL_HOME=$HOME
REAL_BEFORE=$(real_before)
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
has() { printf '%s' "$2" | grep -qF -- "$1" && echo yes || echo no; }  # has <needle> <haystack>
line_of() { printf '%s\n' "$2" | grep -nF -- "$1" | head -n 1 | cut -d: -f1; }  # line_of <needle> <haystack>

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

mkdir -p "$SANDBOX/bin"
# Stub ssh: logs the call, refuses the hosts in STUB_DOWN, else runs the
# remote command here as that host.
cat > "$SANDBOX/bin/ssh" <<'EOF'
#!/bin/bash
printf 'ssh %s\n' "$*" >> "$STUB_LOG"
while [ $# -gt 0 ]; do case $1 in -o) shift 2 ;; -*) shift ;; *) break ;; esac; done
host=$1; shift
case " ${STUB_DOWN:-} " in *" $host "*) echo "ssh: connect to host $host port 22: Operation timed out" >&2; exit 255 ;; esac
STUB_HOST=$host exec bash -c "$*"
EOF
# Stub zsh: only the login shell's -lc is expected.
cat > "$SANDBOX/bin/zsh" <<'EOF'
#!/bin/bash
printf 'zsh %s\n' "$1" >> "$STUB_LOG"
[ "$1" = -lc ] || exit 97
exec bash -c "$2"
EOF
# Stub planlab: logs each argument bracketed, prints login's transcript on
# stderr, and approves unless its host is in STUB_DENY.
cat > "$SANDBOX/bin/planlab" <<'EOF'
#!/bin/bash
who=${STUB_HOST:-local}
# One write per line: two machines' logins append at the same time.
line="planlab@$who$(printf ' [%s]' "$@")"; printf '%s\n' "$line" >> "$STUB_LOG"
code=$(printf '%s' "$who" | tr a-z A-Z)-0001
cat >&2 <<EOT
Requesting a Backstage token for this device ($who).

  Open:  https://backstage.example/backstage/device
  Code:  $code        (expires in 10 minutes)

Or open https://backstage.example/backstage/device?code=$code
Waiting for approval…  (Ctrl-C to cancel)
EOT
case " ${STUB_DENY:-} " in *" $who "*) echo "Denied in the browser." >&2; exit 1 ;; esac
echo "✓ Approved by you@example.com in your browser." >&2
echo "  Token \"$who\" saved, bound to this device." >&2
EOF
chmod +x "$SANDBOX/bin/"*
export PATH="$SANDBOX/bin:$PATH"

# fresh [manifest]: a new HOME that is mini2, with the working tree's
# twin.toml or the given text as its manifest, and an empty log.
fresh() {
    rm -rf "$SANDBOX/home" "$SANDBOX/log"; mkdir -p "$SANDBOX/home/.config/twin"
    export HOME="$SANDBOX/home" STUB_LOG="$SANDBOX/log"
    unset STUB_DOWN STUB_DENY STUB_HOST TWIN_MANIFEST
    : > "$STUB_LOG"
    echo mini2 > "$HOME/.config/machine"
    if [ $# -gt 0 ]; then printf '%s\n' "$1" > "$HOME/.config/twin/twin.toml"
    else cp "$REPO/twin/.config/twin/twin.toml" "$HOME/.config/twin/twin.toml"; fi
}
log() { cat "$STUB_LOG"; }

CASE=L1; if want; then
    fresh
    out=$("$TOOL" 2>&1); rc=$?
    ok "L1 exit 0" 0 "$rc"
    ok "L1 this machine logs in here" yes "$(has 'planlab@local [backstage] [login]' "$(log)")"
    ok "L1 this machine is not reached over ssh" no "$(has 'ssh -o ConnectTimeout=10 -o BatchMode=yes mini2 ' "$(log)")"
    ok "L1 mini over ssh, without prompting" yes "$(has 'ssh -o ConnectTimeout=10 -o BatchMode=yes mini ' "$(log)")"
    ok "L1 mac over ssh" yes "$(has 'ssh -o ConnectTimeout=10 -o BatchMode=yes mac ' "$(log)")"
    ok "L1 in a login shell" 2 "$(grep -c '^zsh -lc$' "$STUB_LOG")"
    ok "L1 the remote login ran" yes "$(has 'planlab@mac [backstage] [login]' "$(log)")"
    ok "L1 mac's link" yes "$(has 'https://backstage.example/backstage/device?code=MAC-0001' "$out")"
    ok "L1 mini's link" yes "$(has '?code=MINI-0001' "$out")"
    ok "L1 this machine's link" yes "$(has '?code=LOCAL-0001' "$out")"
    last_link=$(printf '%s\n' "$out" | grep -n '?code=' | tail -n 1 | cut -d: -f1)
    first_outcome=$(line_of ': approved' "$out")
    ok "L1 every link before any outcome" yes "$([ -n "$last_link" ] && [ -n "$first_outcome" ] && [ "$last_link" -lt "$first_outcome" ] && echo yes || echo no)"
    ok "L1 three approved" 3 "$(printf '%s\n' "$out" | grep -c ': approved$')"
    ok "L1 what login said after waiting" yes "$(has '    ✓ Approved by you@example.com' "$out")"
fi

CASE=L2; if want; then
    fresh
    "$TOOL" -- --label 'two words' --ttl 7 >/dev/null 2>&1
    ok "L2 options reach the local login intact" yes "$(has 'planlab@local [backstage] [login] [--label] [two words] [--ttl] [7]' "$(log)")"
    ok "L2 and the remote one" yes "$(has 'planlab@mini [backstage] [login] [--label] [two words] [--ttl] [7]' "$(log)")"
fi

CASE=L3; if want; then
    fresh; export STUB_DOWN=mac
    out=$("$TOOL" 2>&1); rc=$?
    ok "L3 exit 1" 1 "$rc"
    ok "L3 names the machine without a code" 1 "$(printf '%s\n' "$out" | grep -cE '^  mac +no code:$')"
    ok "L3 says why" yes "$(has 'ssh: connect to host mac port 22' "$out")"
    ok "L3 the others still approve" 2 "$(printf '%s\n' "$out" | grep -c ': approved$')"
fi

CASE=L4; if want; then
    fresh; export STUB_DENY=mini
    out=$("$TOOL" 2>&1); rc=$?
    ok "L4 exit 1" 1 "$rc"
    ok "L4 names the unapproved login" yes "$(has 'mini: not approved (exit 1)' "$out")"
    ok "L4 with what it said" yes "$(has '    Denied in the browser.' "$out")"
    ok "L4 the others still approve" 2 "$(printf '%s\n' "$out" | grep -c ': approved$')"
fi

CASE=L5; if want; then
    fresh
    out=$("$TOOL" mac 2>&1); rc=$?
    ok "L5 a named machine: exit 0" 0 "$rc"
    ok "L5 only it" 1 "$(grep -c '^planlab@' "$STUB_LOG")"
    ok "L5 and it is mac" yes "$(has 'planlab@mac ' "$(log)")"
    fresh
    out=$("$TOOL" mac nope 2>&1); rc=$?
    ok "L5 an unknown machine: exit 2" 2 "$rc"
    ok "L5 names the machines there are" yes "$(has 'nope is not a machine' "$out")"
    ok "L5 starts nothing" 0 "$(wc -l < "$STUB_LOG" | tr -d ' ')"
    out=$("$TOOL" --ttl 7 2>&1); rc=$?
    ok "L5 a login option before --: exit 2" 2 "$rc"
    ok "L5 says where it goes" yes "$(has 'login options go after --' "$out")"
fi

CASE=L6; if want; then
    # The alias comes from the manifest; a table without one is its own name.
    fresh '[machines.laptop]
ssh = "qiushi-mac"

[machines.box]
packages = ["zsh"]

[dotfiles]
ssh = "not-a-machine"'
    "$TOOL" >/dev/null 2>&1
    ok "L6 the manifest's alias" yes "$(has 'BatchMode=yes qiushi-mac ' "$(log)")"
    ok "L6 the name when there is none" yes "$(has 'BatchMode=yes box ' "$(log)")"
    ok "L6 nothing outside [machines.*]" no "$(has 'not-a-machine' "$(log)")"
    ok "L6 two machines" 2 "$(grep -c '^planlab@' "$STUB_LOG")"
fi

CASE=Z1; if want; then
    export HOME=$REAL_HOME
    ok "Z1 the real ~/.planlab/.env is untouched" "$REAL_BEFORE" "$(real_before)"
fi

echo "planlab-login-all: $PASS passed, $FAIL failed${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
