#!/usr/bin/env bash
# test-rex-clipshare.sh — rex-clipshare's push of a Rex copy to every other
# machine's pasteboard, which is what lets nvim's p on one host paste what
# was yanked on another.
#
# Usage: bash test-rex-clipshare.sh [C1 C4 ...]
#
# What this pins: the copy reaches each peer in twin's manifest and never
# this machine (C1); the command returns before a slow push finishes, since
# rexd hears no events while it waits (C2); a newer copy is never overwritten
# by an older one still in flight (C3); a peer that is down is logged and the
# others still get the copy (C4); text with newlines and quotes arrives byte
# for byte (C5); no manifest means no pushes (C6).
#
# ISOLATION. ssh is a stub at the head of PATH that writes each peer's
# "pasteboard" to a sandbox file, so no connection is made and no real
# pasteboard is touched. The manifest, this machine's name and the copy's
# directory are the script's test seams, all inside the sandbox.

set -uo pipefail

TOOL="$(cd "$(dirname "$0")/../../../../../rex/.local/bin" && pwd)/rex-clipshare"
PASS=0; FAIL=0; FAILED=""
SANDBOX=$(mktemp -d /tmp/rex-clipshare-test.XXXXXX)
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

mkdir -p "$SANDBOX/bin"
# The stub: ssh [opts] ALIAS /usr/bin/pbcopy, stdin the copy. SLOW_<alias>
# seconds of delay before reading, DOWN_<alias> fails without reading.
cat > "$SANDBOX/bin/ssh" <<'EOF'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do case $1 in -o) shift 2 ;; *) break ;; esac; done
alias=$1 cmd=$2
[ "$cmd" = /usr/bin/pbcopy ] || exit 97
down="DOWN_$alias"; [ -n "${!down:-}" ] && exit 255
slow="SLOW_$alias"; [ -n "${!slow:-}" ] && sleep "${!slow}"
cat > "$STUB_OUT/$alias.tmp" && mv "$STUB_OUT/$alias.tmp" "$STUB_OUT/$alias"
EOF
chmod +x "$SANDBOX/bin/ssh"

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

# run CASE_DIR SELF [VAR=VALUE...] < text: one copy, from machine SELF.
run() {
    local dir=$1 self=$2; shift 2
    mkdir -p "$dir/out"
    env "$@" PATH="$SANDBOX/bin:$PATH" STUB_OUT="$dir/out" \
        REX_CLIPSHARE_TWIN="${TWIN-$SANDBOX/twin.toml}" REX_CLIPSHARE_SELF="$self" \
        REX_CLIPSHARE_DIR="$dir/state" "$TOOL"
}
# settle DIR ALIAS...: wait until each named peer has a pasteboard file.
settle() {
    local dir=$1; shift
    for _ in $(seq 100); do
        local all=1
        for a in "$@"; do [ -f "$dir/out/$a" ] || all=0; done
        [ $all = 1 ] && return; sleep 0.05
    done
}
board() { cat "$1/out/$2" 2>/dev/null || printf '(none)'; }

CASE=C1; if want; then
    d="$SANDBOX/c1"
    printf 'yanked on mini2' | run "$d" mini2
    settle "$d" mac mini; sleep 0.3
    ok "C1 the laptop gets the copy" "yanked on mini2" "$(board "$d" mac)"
    ok "C1 the mini gets the copy" "yanked on mini2" "$(board "$d" mini)"
    ok "C1 this machine is not pushed to" "(none)" "$(board "$d" mini2)"
    ok "C1 only machines are peers" "mac mini" "$(ls "$d/out" | tr '\n' ' ' | sed 's/ $//')"
fi

CASE=C2; if want; then
    d="$SANDBOX/c2"
    start=$(date +%s)
    printf 'slow' | run "$d" mac SLOW_mini=2
    took=$(( $(date +%s) - start ))
    ok "C2 returns before a slow push finishes" "yes" "$([ $took -lt 2 ] && echo yes || echo "no (${took}s)")"
    settle "$d" mini
    ok "C2 the slow push still lands" "slow" "$(board "$d" mini)"
fi

CASE=C3; if want; then
    d="$SANDBOX/c3"
    printf 'older' | run "$d" mac SLOW_mini=1
    sleep 0.2
    printf 'newer' | run "$d" mac
    sleep 2.5
    ok "C3 the newest copy wins over one still in flight" "newer" "$(board "$d" mini)"
    ok "C3 an unslowed peer has the newest too" "newer" "$(board "$d" mini2)"
fi

CASE=C4; if want; then
    d="$SANDBOX/c4"
    printf 'partial' | run "$d" mac DOWN_mini=1
    settle "$d" mini2; sleep 0.3
    ok "C4 a live peer gets the copy" "partial" "$(board "$d" mini2)"
    ok "C4 the down peer is logged" "1" "$(grep -c ' mini: push failed' "$d/state/log" 2>/dev/null || echo 0)"
fi

CASE=C5; if want; then
    d="$SANDBOX/c5"
    text=$(printf 'line one\n  it'"'"'s "two"\t$HOME `x`\n')
    printf '%s' "$text" | run "$d" mac
    settle "$d" mini mini2
    ok "C5 text arrives byte for byte" "$(printf '%s' "$text" | shasum)" "$(board "$d" mini | shasum)"
fi

CASE=C6; if want; then
    d="$SANDBOX/c6"
    printf 'nowhere' | TWIN="$SANDBOX/absent.toml" run "$d" mac
    sleep 0.3
    ok "C6 no manifest, no pushes" "" "$(ls "$d/out")"
fi

echo "$PASS passed, $FAIL failed${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
