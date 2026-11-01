#!/usr/bin/env bash
# test-rex-clipshare.sh — rex-clipshare, the one place a Rex copy is
# published: onto this machine's pasteboard and every other machine's, so
# nvim's p on one host pastes what was copied in a Rex pane on another.
#
# Usage: bash test-rex-clipshare.sh [C1 C4 ... R1]
#
# What this pins: a copy lands here at once and on each peer in twin's
# manifest (C1); the command returns before a slow push lands, since rexd
# hears no events while it waits (C2); a late push never lands over a newer
# copy, from the same machine (C3) or another (C4), nor a stale stamp over a
# newer one (C5); a peer that is down is logged and the others still get it
# (C6); text arrives byte for byte, trailing newlines and non-ASCII included,
# with a UTF-8 locale for pbcopy (C7); no manifest still copies here (C8).
# R1 drives the production join on a scratch Rex server: a terminal's OSC 52
# write, small and too large for its event, reaches rex-clipshare through
# rexd; it needs rex and skips without it.
#
# ISOLATION. Each machine is a sandbox directory: its "pasteboard" is a file
# a stub pbcopy writes, its state is REX_CLIPSHARE_DIR. A stub ssh at the
# head of PATH runs the peer's side (rex-clipshare receive) against that
# peer's sandbox, so no connection is made and no real pasteboard is
# touched. R1 runs its own Rex server under a short temporary HOME with
# REX_* stripped, and a stub rex-clipshare there records what rexd hands it;
# rexd's fallback writes the real pasteboard, so R1 asserts it untouched.

set -uo pipefail

TOOL="$(cd "$(dirname "$0")/../../../../../rex/.local/bin" && pwd)/rex-clipshare"
REX_CFG="$(cd "$(dirname "$0")/../../../../../rex/.config/rex" && pwd)"
PASS=0; FAIL=0; SKIP=0; FAILED=""
SANDBOX=$(mktemp -d /tmp/rex-clipshare-test.XXXXXX)
SERVER_PID=
cleanup() {
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
    [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }
    rm -rf "${SANDBOX:-}" "${RHOME:-}"
}
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

mkdir -p "$SANDBOX/bin"
# pbcopy: write the machine's pasteboard (MACHINE_DIR/board) and the locale
# it ran under.
cat > "$SANDBOX/bin/pbcopy" <<'EOF'
#!/bin/sh
cat > "$MACHINE_DIR/board.tmp" && mv "$MACHINE_DIR/board.tmp" "$MACHINE_DIR/board"
printf %s "$LANG" > "$MACHINE_DIR/lang"
EOF
# ssh [opts] ALIAS 'CMD receive STAMP': the peer's side, in its sandbox.
# SLOW_<alias> seconds before it runs, or until GATE_<alias> exists;
# DOWN_<alias> fails without running.
cat > "$SANDBOX/bin/ssh" <<'EOF'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do case $1 in -o) shift 2 ;; *) break ;; esac; done
alias=$1 cmd=$2
case $cmd in *' receive '*) stamp=${cmd##* receive } ;; *) exit 97 ;; esac
down="DOWN_$alias"; [ -n "${!down:-}" ] && exit 255
slow="SLOW_$alias"; [ -n "${!slow:-}" ] && sleep "${!slow}"
gate="GATE_$alias"
if [ -n "${!gate:-}" ]; then while [ ! -e "${!gate}" ]; do sleep 0.05; done; fi
MACHINE_DIR="$WORLD/$alias" REX_CLIPSHARE_DIR="$WORLD/$alias/state" \
  REX_CLIPSHARE_SELF="$alias" exec "$TOOL" receive "$stamp"
EOF
chmod +x "$SANDBOX/bin/pbcopy" "$SANDBOX/bin/ssh"

cat > "$SANDBOX/twin.toml" <<'EOF'
reconciles = "mini"

[machines.mac]
ssh = "mac"

[machines.mini]
ssh = "mini"
packages = ["rex"]

[machines.mini2]
ssh = "mini2"

[dotfiles]
repo = "dotfiles"
ssh = "not-a-machine"
EOF

# world NAME: a fresh set of three machines.
world() { WORLD="$SANDBOX/$1"; for m in mac mini mini2; do mkdir -p "$WORLD/$m"; done; }
# publish SELF [VAR=VALUE...] < text: one copy published on machine SELF.
publish() {
    local self=$1; shift
    env "$@" PATH="$SANDBOX/bin:$PATH" WORLD="$WORLD" TOOL="$TOOL" \
        MACHINE_DIR="$WORLD/$self" REX_CLIPSHARE_DIR="$WORLD/$self/state" \
        REX_CLIPSHARE_TWIN="${TWIN-$SANDBOX/twin.toml}" REX_CLIPSHARE_SELF="$self" "$TOOL"
}
board() { cat "$WORLD/$1/board" 2>/dev/null || printf '(none)'; }
# settle M TEXT...: wait until machine M's pasteboard reads TEXT.
settle() { for _ in $(seq 100); do [ "$(board "$1")" = "$2" ] && return; sleep 0.05; done; }

CASE=C1; if want; then
    world c1
    printf 'yanked on mini2' | publish mini2
    ok "C1 this machine has the copy when the command returns" "yanked on mini2" "$(board mini2)"
    settle mac 'yanked on mini2'; settle mini 'yanked on mini2'
    ok "C1 the laptop gets the copy" "yanked on mini2" "$(board mac)"
    ok "C1 the mini gets the copy" "yanked on mini2" "$(board mini)"
fi

CASE=C2; if want; then
    world c2
    start=$(date +%s)
    printf 'slow' | publish mac SLOW_mini=2
    took=$(( $(date +%s) - start ))
    ok "C2 returns before a slow push lands" "yes" "$([ $took -lt 2 ] && echo yes || echo "no (${took}s)")"
    settle mini slow
    ok "C2 the slow push still lands" "slow" "$(board mini)"
fi

CASE=C3; if want; then
    world c3
    printf 'older' | publish mac GATE_mini="$WORLD/open"
    sleep 0.1
    printf 'newer' | publish mac
    settle mini newer
    touch "$WORLD/open"; sleep 1
    ok "C3 a late push from this machine does not land over a newer copy" "newer" "$(board mini)"
    ok "C3 the sender keeps the newer copy" "newer" "$(board mac)"
fi

CASE=C4; if want; then
    world c4
    printf 'from the laptop, older' | publish mac GATE_mini="$WORLD/open"
    sleep 0.1
    printf 'from mini2, newer' | publish mini2
    settle mini 'from mini2, newer'
    touch "$WORLD/open"; sleep 1
    ok "C4 a late push from another machine does not land over a newer copy" "from mini2, newer" "$(board mini)"
    ok "C4 every machine agrees on the newest" "from mini2, newer|from mini2, newer" "$(board mac)|$(board mini2)"
fi

CASE=C5; if want; then
    world c5
    printf 'current' | publish mini
    printf 'stale' | env PATH="$SANDBOX/bin:$PATH" MACHINE_DIR="$WORLD/mini" \
        REX_CLIPSHARE_DIR="$WORLD/mini/state" "$TOOL" receive 1.000000
    ok "C5 a copy stamped before the last one taken is dropped" "current" "$(board mini)"
fi

CASE=C6; if want; then
    world c6
    printf 'partial' | publish mac DOWN_mini=1
    settle mini2 partial; sleep 0.3
    ok "C6 a live peer gets the copy" "partial" "$(board mini2)"
    ok "C6 the down peer is logged" "1" "$(grep -c ' mini: push failed' "$WORLD/mac/state/log" 2>/dev/null || echo 0)"
fi

CASE=C7; if want; then
    world c7
    printf 'line one\n  it'"'"'s "two"\t$HOME `x` café 中文\n\n' > "$SANDBOX/c7.txt"
    publish mac < "$SANDBOX/c7.txt"
    for _ in $(seq 100); do cmp -s "$SANDBOX/c7.txt" "$WORLD/mini/board" && break; sleep 0.05; done
    ok "C7 text lands here byte for byte" "same" "$(cmp -s "$SANDBOX/c7.txt" "$WORLD/mac/board" && echo same || echo differs)"
    ok "C7 text lands on a peer byte for byte" "same" "$(cmp -s "$SANDBOX/c7.txt" "$WORLD/mini/board" && echo same || echo differs)"
    ok "C7 pbcopy runs under a UTF-8 locale" "en_US.UTF-8" "$(cat "$WORLD/mini/lang" 2>/dev/null)"
fi

CASE=C8; if want; then
    world c8
    printf 'nowhere else' | TWIN="$SANDBOX/absent.toml" publish mac
    sleep 0.3
    ok "C8 no manifest still copies here" "nowhere else" "$(board mac)"
    ok "C8 no manifest, no pushes" "(none)|(none)" "$(board mini)|$(board mini2)"
fi

# R1: a scratch Rex server, rexd.lua from the working tree, a stub
# rex-clipshare that keeps each copy rexd publishes.
CASE=R1; if want; then
  REX=$(command -v rex || true)
  if [ -z "$REX" ]; then SKIP=$((SKIP+1)); echo "  skip R1: no rex"; else
    REAL_CLIP_BEFORE=$(/usr/bin/pbpaste | shasum)
    RHOME=$(mktemp -d /tmp/rcs.XXXX)
    mkdir -p "$RHOME/.config" "$RHOME/.local/bin" "$RHOME/got"
    ln -s "$REX_CFG" "$RHOME/.config/rex"
    cat > "$RHOME/.local/bin/rex-clipshare" <<EOF
#!/bin/sh
cat > "\$(mktemp "$RHOME/got/copy.XXXXXX")"
EOF
    chmod +x "$RHOME/.local/bin/rex-clipshare"
    R() { env -u REX_SERVER -u REX_SESSION -u REX_BLOCK -u TMUX HOME="$RHOME" "$REX" "$@"; }
    R server run >"$RHOME/server.log" 2>&1 &
    SERVER_PID=$!
    for _ in $(seq 100); do R --autostart=false ls >/dev/null 2>&1 && break; sleep 0.1; done
    R --autostart=false new rcs --shell=none -- /bin/sleep 600 >/dev/null 2>&1
    R --autostart=false do "$REX_CFG/scripts/rexd.lua" --all >"$RHOME/rexd.log" 2>&1 &
    RDPID=$!
    sleep 1.5
    head -c 300000 /dev/urandom | base64 | tr -d '\n' | head -c 300000 > "$RHOME/big.txt"
    printf 'small copy é' > "$RHOME/small.txt"
    found() { for g in "$RHOME"/got/*; do cmp -s "$g" "$RHOME/$1.txt" && { echo yes; return; }; done; echo no; }
    for f in small big; do
      R --autostart=false run -s rcs --shell=none -- /bin/sh -c "printf '\\033]52;c;%s\\007' \"\$(base64 < '$RHOME/$f.txt' | tr -d '\\n')\"; sleep 2" >/dev/null 2>&1
      for _ in $(seq 60); do [ "$(found $f)" = yes ] && break; sleep 0.1; done
    done
    ok "R1 rexd publishes a terminal's OSC 52 copy" "yes" "$(found small)"
    ok "R1 rexd publishes a copy too large for its event, whole" "yes" "$(found big)"
    # rexd falls back to the real /usr/bin/pbcopy when publishing fails.
    ok "R1 the real pasteboard is untouched" "$REAL_CLIP_BEFORE" "$(/usr/bin/pbpaste | shasum)"
    kill "$RDPID" 2>/dev/null
  fi
fi

echo "$PASS passed, $FAIL failed${SKIP:+, $SKIP skipped}${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
