#!/usr/bin/env bash
# test-rex-open.sh — opening a pane's URL or file on the machine the person is
# at: the picker behind Rex's prefix u (rex-urls), the transfer (rex-open), and
# the action's name for that machine (rexkit.host.viewer).
#
# Usage: bash test-rex-open.sh [O1 O2 ... P1 P2 ... V1]    # V1 requires rex
#
# ISOLATION. Each machine is a sandbox HOME holding links to the tools. Stubs at
# the head of PATH stand in for ssh (runs the far command under that machine's
# HOME, with stdin), open (records its argument), fzf (picks by a variable), rex
# (prints a fixture capture) and sleep. No connection is made and nothing opens.
# V1 uses a scratch Rex server under a short temporary HOME with REX_* stripped.

set -uo pipefail

REPO="$(cd "$(dirname "$0")/../../../../.." && pwd)"
PASS=0; FAIL=0; SKIP=0; FAILED=""
SANDBOX=$(cd "$(mktemp -d /tmp/rex-open-test.XXXXXX)" && pwd -P)
SERVER_PID=; VHOME=
cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
  [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }
  rm -rf "${SANDBOX:-}" "${VHOME:-}"
}
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
yn() { "$@" && echo yes || echo no; }
ONLY=("$@")

BIN=$SANDBOX/bin; mkdir -p "$BIN"
export SANDBOX
# ssh [-o X]... ALIAS CMD: CMD runs under ALIAS's HOME, unless SSH_DOWN names it.
cat > "$BIN/ssh" <<'STUB'
#!/usr/bin/env bash
while [ "$1" = -o ]; do printf '%s ' "$2" >> "$SANDBOX/ssh-args"; shift 2; done
alias=$1 cmd=$2
echo "$alias" >> "$SANDBOX/ssh-args"
[ "${SSH_DOWN:-}" = "$alias" ] && { echo "ssh: connect to host $alias: timed out" >&2; exit 255; }
HOME=$SANDBOX/$alias WHO=$alias exec /bin/sh -c "$cmd"
STUB
cat > "$BIN/open" <<'STUB'
#!/bin/sh
echo "$WHO $1" >> "$SANDBOX/opened"
STUB
# fzf: keeps the list, reports FZF_KEY and the FZF_LINE'th line; none is esc.
cat > "$BIN/fzf" <<'STUB'
#!/bin/sh
cat > "$SANDBOX/listed"
[ -n "${FZF_LINE:-}" ] || exit 130
printf '%s\n' "${FZF_KEY:-enter}"
sed -n "${FZF_LINE}p" "$SANDBOX/listed"
STUB
cat > "$BIN/rex" <<'STUB'
#!/bin/sh
cat "$SANDBOX/capture"
STUB
printf '#!/bin/sh\nexit 0\n' > "$BIN/sleep"
chmod +x "$BIN"/*

machine() {  # a machine's HOME, its name, and the tools linked as stow does
  mkdir -p "$SANDBOX/$1/.config" "$SANDBOX/$1/.local/bin"
  echo "$1" > "$SANDBOX/$1/.config/machine"
  ln -sf "$REPO/rex/.local/bin/rex-open" "$REPO/rex/.local/bin/rex-urls" "$SANDBOX/$1/.local/bin/"
}
machine laptop; machine host
clean() { rm -f "$SANDBOX/opened" "$SANDBOX/ssh-args" "$SANDBOX/listed"; rm -rf "$SANDBOX/laptop/.cache"; }
on_host() { HOME="$SANDBOX/host" WHO=host PATH="$BIN:$PATH" "$@"; }
OPEN=$REPO/rex/.local/bin/rex-open
URLS=$REPO/rex/.local/bin/rex-urls
pick() {  # pick <line> [key] [machine]: the picker on the host, for that viewer
  (cd "$SANDBOX/host/work" && FZF_LINE=$1 FZF_KEY=${2:-enter} on_host bash "$URLS" s b "${3:-laptop}")
}
opened() { cat "$SANDBOX/opened" 2>/dev/null; }
sent() { find "$SANDBOX/laptop/.cache/rex-open" -type f -name "$1" 2>/dev/null | head -1; }

mkdir -p "$SANDBOX/host/work/src" "$SANDBOX/host/out"
SRC=$SANDBOX/host/work/report.png
head -c 5000 /dev/urandom > "$SRC"

CASE=O1; if want; then clean
  on_host bash "$OPEN" laptop "$SRC"; rc=$?
  f=$(sent report.png)
  ok "O1 a file reaches the machine named, byte for byte" "0 yes" "$rc $(yn cmp -s "$f" "$SRC")"
  ok "O1 it opens there, not here" "laptop $f" "$(opened)"
  ok "O1 it is quarantined as a download is" "yes" \
    "$(xattr -p com.apple.quarantine "$f" 2>/dev/null | grep -E '^0083;[0-9a-f]+;rex-open;$' >/dev/null && echo yes || echo no)"
  ok "O1 no partial file stays" "0" "$(find "$SANDBOX/laptop/.cache" -name '.part' | wc -l | tr -d ' ')"
  ok "O1 a dead machine fails fast" "BatchMode=yes ConnectTimeout=3 laptop" "$(cat "$SANDBOX/ssh-args")"
fi

CASE=O2; if want; then clean
  out=$(printf short | HOME="$SANDBOX/laptop" WHO=laptop PATH="$BIN:$PATH" bash "$OPEN" receive report.png 999 2>&1); rc=$?
  ok "O2 a short stream fails, naming the shortfall" "1 rex-open: got 5 of 999 bytes" "$rc $out"
  ok "O2 and opens nothing" "" "$(opened)"
  ok "O2 and keeps nothing" "0" "$(find "$SANDBOX/laptop/.cache/rex-open" -mindepth 1 | wc -l | tr -d ' ')"
fi

CASE=O3; if want; then clean
  on_host bash "$OPEN" host "$SRC"
  ok "O3 at this machine it is plain open" "host $SRC" "$(opened)"
  ok "O3 with no ssh" "no" "$(yn test -e "$SANDBOX/ssh-args")"
fi

CASE=O4; if want; then clean
  on_host bash "$OPEN" laptop 'https://example.com/a?b=1&c=$(x)'
  ok "O4 a URL opens on the machine named, whole" 'laptop https://example.com/a?b=1&c=$(x)' "$(opened)"
  clean; printf 'javascript:alert(1)\n' | HOME="$SANDBOX/laptop" WHO=laptop PATH="$BIN:$PATH" bash "$OPEN" receive-url >/dev/null 2>&1; rc=$?
  ok "O4 the far side refuses any other scheme" "1 " "$rc $(opened)"
fi

CASE=O5; if want; then clean
  out=$(SSH_DOWN=laptop on_host bash "$OPEN" laptop "$SRC" 2>&1); rc=$?
  ok "O5 a machine that is down fails with ssh's reason" "255 ssh: connect to host laptop: timed out" "$rc $out"
  clean; on_host bash "$OPEN" laptop "$SANDBOX/host/nope.png" >/dev/null 2>&1; rc=$?
  ok "O5 a missing file fails before any connection" "1 no" "$rc $(yn test -e "$SANDBOX/ssh-args")"
fi

CASE=O6; if want; then clean
  odd=$SANDBOX/host/work/'a b;$(touch PWNED).png'; head -c 10 /dev/urandom > "$odd"
  (cd "$SANDBOX/laptop" && on_host bash "$OPEN" laptop "$odd"); rc=$?
  ok "O6 an awkward name runs nothing on the far side" "0 " "$rc $(find "$SANDBOX" -name PWNED)"
  ok "O6 and arrives under a name that needs no quoting" "a_b___touch_PWNED_.png" "$(basename "$(sent 'a_b*')")"
  rm -f "$odd"
fi

# A screen as fullscreen Claude Code draws it, its renderer's own breaks kept.
L=$SANDBOX/host/work/a-rather-long-directory-name-to-force-wrapping-at-eighty/and-another-long-segment-here
mkdir -p "$L"
FULL=$L/report-final-version.png
for f in "$FULL" "$SANDBOX/host/work/short.txt" "$SANDBOX/host/work/src/app.ts" "$SANDBOX/host/work/src/line.ts" "$SANDBOX/host/out/tilde.txt"; do printf x > "$f"; done
P1=$SANDBOX/host/work/a-rather-long-direct
P2=ory-name-to-force-wrapping-at-eighty/and-another-long-segment-here/report-final
P3=-version.png
cat > "$SANDBOX/capture" <<SCREEN
❯ Run: ls

⏺ Bash(ls $P1
  $P2
  $P3)
  ⎿  ~/out/tilde.txt and a word
  see src/line.ts:12:3 then a/src/app.ts, and /no/such/file.png
⏺ https://example.com/old, then short.txt.
  A prose row that ends in a path that does not exist /no/such/
  next-row-word
  https://example.com/new
SCREEN

CASE=P1; if want; then clean
  pick "" >/dev/null 2>&1
  ok "P1 the list: newest first, each once, whole paths only, broken ones rejoined" \
"https://example.com/new
$SANDBOX/host/work/short.txt
https://example.com/old
$SANDBOX/host/work/src/app.ts
$SANDBOX/host/work/src/line.ts
$SANDBOX/host/out/tilde.txt
$FULL" "$(cat "$SANDBOX/listed" 2>/dev/null)"
fi

CASE=P2; if want; then clean
  pick 7 >/dev/null 2>&1
  f=$(sent report-final-version.png)
  ok "P2 enter on a rejoined file sends it to the viewer and opens it" "laptop $f" "$(opened)"
  ok "P2 the sent file is not empty" "yes" "$(yn test -s "$f")"
  clean; pick 1 >/dev/null 2>&1
  ok "P2 enter on a URL opens it on the viewer" "laptop https://example.com/new" "$(opened)"
fi

CASE=P3; if want; then clean
  out=$(pick 2 ctrl-y 2>&1)
  ok "P3 ctrl-y copies the absolute path through the terminal" \
    "$(printf '\033]52;c;%s\a' "$(printf %s "$SANDBOX/host/work/short.txt" | base64 | tr -d '\n')")" "$out"
  ok "P3 and opens nothing" "" "$(opened)"
fi

has() { case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac; }
CASE=P4; if want; then clean
  out=$(pick 2 enter unknown 2>&1)
  ok "P4 an unknown machine copies and says so, opening nothing" "yes yes " \
    "$(has "$out" $'\e]52;c;') $(has "$out" 'cannot tell which machine you are at') $(opened)"
  clean; out=$(SSH_DOWN=laptop pick 2 2>&1)
  ok "P4 a machine that is down copies and names why" "yes yes" \
    "$(has "$out" $'\e]52;c;') $(has "$out" 'not opened on laptop, copied it instead: ssh: connect to host laptop: timed out')"
fi

CASE=V1; if want; then
  REX=$(command -v rex || true)
  if [ -z "$REX" ]; then SKIP=$((SKIP+1)); echo "  skip V1: no rex"; else
    VHOME=$(mktemp -d /tmp/rop.XXXX)
    mkdir -p "$VHOME/.config"; ln -s "$REPO/rex/.config/rex" "$VHOME/.config/rex"; echo mac > "$VHOME/.config/machine"
    R() { env -u REX_SERVER -u REX_SESSION -u REX_BLOCK -u TMUX HOME="$VHOME" "$REX" --autostart=false "$@"; }
    # exec in the subshell, so $! is the server and the cleanup stops it.
    ( exec env -u REX_SERVER -u REX_SESSION -u REX_BLOCK -u TMUX HOME="$VHOME" "$REX" server run ) >"$VHOME/server.log" 2>&1 &
    SERVER_PID=$!
    for _ in $(seq 100); do R ls >/dev/null 2>&1 && break; sleep 0.1; done
    view() {  # view <ctx> <the client's transport>
      R do -e "package.path = '$REPO/rex/.config/rex/lua/?.lua;' .. package.path
        require('rexkit.api').try = function() return { client = { principal = { transport = '$2' } } } end
        return require('rexkit.host').viewer($1)" 2>&1 | tr -d '"'
    }
    ok "V1 another host's pane names this machine" "mac" "$(view '{ server = "m2" }' tailscale)"
    ok "V1 a local client names this machine" "mac" "$(view '{ client_id = "c" }' unix)"
    ok "V1 a client elsewhere with no server cannot name one" "unknown" "$(view '{ client_id = "c" }' tailscale)"
    rm -f "$VHOME/.config/machine"
    ok "V1 no machine file cannot name one" "unknown" "$(view '{ server = "m2" }' tailscale)"
  fi
fi

echo "$PASS passed, $FAIL failed${SKIP:+, $SKIP skipped}${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
