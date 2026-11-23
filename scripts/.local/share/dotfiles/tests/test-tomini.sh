#!/usr/bin/env bash
# test-tomini.sh — tomini, which sends this machine's clipboard, text or
# image, to another machine's pasteboard over ssh.
#
# Usage: bash test-tomini.sh [T1 T2]
#
# What this pins: MINI_HOST picks the machine and a dead host fails fast (T1);
# a clipboard it cannot read never reaches ssh (T2).
#
# ISOLATION. Each case runs tomini under a sandbox HOME whose pasteboard
# reader is a stub, with a stub ssh at the head of PATH that records its
# arguments and what it was sent, so no connection is made and no real
# pasteboard is read.

set -uo pipefail

TOMINI="$(cd "$(dirname "$0")/../../.." && pwd)/bin/tomini"
PASS=0; FAIL=0; FAILED=""
SANDBOX=$(mktemp -d /tmp/tomini-test.XXXXXX)
cleanup() {
    [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }
    case "$SANDBOX" in /tmp/tomini-test.*) rm -rf "$SANDBOX" ;; esac
}
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

# T1, T2: tomini against a stub pasteboard and ssh, under a sandbox HOME.
tomini_run() {  # tomini_run <dir> <pasteboard get body>: its exit status, ssh's calls in <dir>/ssh
  local d=$1
  mkdir -p "$d/home/dotfiles/scripts/.local/share/dotfiles" "$d/bin"
  { printf '#!/bin/sh\n'; printf '%s\n' "$2"; } > "$d/home/dotfiles/scripts/.local/share/dotfiles/pasteboard"
  printf '#!/bin/sh\nwhile [ "$1" = -o ]; do printf "%%s " "$2" >> "%s/ssh"; shift 2; done; echo "$1" >> "%s/ssh"; cat >> "%s/sent"\n' "$d" "$d" "$d" > "$d/bin/ssh"
  chmod +x "$d/home/dotfiles/scripts/.local/share/dotfiles/pasteboard" "$d/bin/ssh"
  HOME="$d/home" PATH="$d/bin:$PATH" MINI_HOST=${3:-mini2} \
    bash "$TOMINI" >/dev/null 2>&1
}
CASE=T1; if want; then
  d=$SANDBOX/t1
  tomini_run "$d" 'printf hello > "$2/clip.txt"; echo "$2/clip.txt"'
  ok "T1 tomini sends to the machine MINI_HOST names, failing fast if it is dead" \
    "BatchMode=yes ConnectTimeout=3 mini2 hello" "$(cat "$d/ssh" 2>/dev/null) $(cat "$d/sent" 2>/dev/null)"
fi
CASE=T2; if want; then
  d=$SANDBOX/t2
  tomini_run "$d" 'exit 1'; rc=$?
  ok "T2 a clipboard tomini cannot read fails and never reaches ssh" "1 no" "$rc $([ -e "$d/ssh" ] && echo yes || echo no)"
fi

echo "$PASS passed, $FAIL failed${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
