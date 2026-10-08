#!/usr/bin/env bash
# test-toclip.sh — toclip's routing: which clipboard a copy is sent to, and
# browser-clip's, which follows it: which screen a URL opens on.
#
# Usage: bash test-toclip.sh [K1 K5 ...]
#
# The traps this pins: a session can be on both screens at once, the laptop's
# ssh client and the mini's own, and a copy belongs to the one last typed at.
# Sending to the ssh client whenever one is attached strands a copy made at the
# mini's desk on the laptop (K13, K14); sending to the newest attach strands
# the laptop's (K5, K11). toclip has to know which machine its pick is on, so
# it makes the pick itself and names that client to `tmux load-buffer -w`. And
# a pane keeps the environment it was created with: one made over ssh, viewed
# now at the mini's own screen, must still open URLs there (K10).
#
# ISOLATION. tmux runs on a private socket (every toclip call gets $TMUX
# pointed at it), pbcopy and open are stubs on PATH that record what they were
# given, and TOCLIP_REMOTE_PIDS decides which clients count as ssh instead of
# walking the real process tree. K8 asserts the real clipboard was never
# touched.

set -uo pipefail

TOCLIP="$(cd "$(dirname "$0")/../../../bin" && pwd)/toclip"
BROWSER_CLIP="$(dirname "$TOCLIP")/browser-clip"
PASS=0; FAIL=0; FAILED=""

# Short path: a unix socket path over ~104 bytes fails to bind.
SANDBOX=$(mktemp -d /tmp/toclip-test.XXXXXX)
SOCK="$SANDBOX/s"
REAL_CLIP_BEFORE=$(pbpaste | shasum)
# KEEP=1 leaves the sandbox (client typescripts included) for inspection.
cleanup() { tmux -S "$SOCK" kill-server 2>/dev/null; [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}

want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/pbcopy" <<EOF
#!/bin/sh
cat > "$SANDBOX/pbcopy.out"
EOF
cat > "$SANDBOX/bin/open" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$SANDBOX/open.out"
EOF
chmod +x "$SANDBOX/bin/pbcopy" "$SANDBOX/bin/open"
export PATH="$SANDBOX/bin:$PATH"
unset SSH_CONNECTION SSH_TTY

R() { tmux -S "$SOCK" "$@"; }

# A fresh server with session s; prints nothing. Clients are attached per case.
fresh() {
    R kill-server 2>/dev/null
    rm -f "$SANDBOX"/pbcopy.out "$SANDBOX"/open.out "$SANDBOX"/ts.*
    R -f /dev/null new-session -d -s s -x 80 -y 20
    R set -g set-clipboard on
    R set -g history-limit 100
    R bind -n F12 set -q @typed 1   # typed()'s key: counts as input, reaches no pane
}

# attach <name>: a real client on a pty via script(1); prints its pid.
attach() {
    ( script -q "$SANDBOX/ts.$1" env TERM=xterm-256color tmux -S "$SOCK" attach -t s \
        < /dev/null > /dev/null 2>&1 & )
    local i; for i in $(seq 1 30); do
        sleep 0.1
        R list-clients -F '#{client_pid} #{client_tty}' | while read -r pid tty; do
            grep -qx "$tty" "$SANDBOX/ttys" 2>/dev/null || { echo "$tty" >> "$SANDBOX/ttys"; echo "$pid"; }
        done | grep . && return
    done
}

# typed <pid>: a keypress at that client, which makes it the session's most
# recently active one. client_activity has one-second resolution.
typed() {
    sleep 1.1
    R send-keys -K -c "$(R list-clients -F '#{client_pid} #{client_name}' | awk -v p="$1" '$1 == p { print $2 }')" F12
}

# Run toclip, or browser-clip, as from pane %0 of the sandbox server.
T() { TMUX="$SOCK,$(R display -p '#{pid}'),0" TMUX_PANE=%0 "$TOCLIP" "$@"; }
B() { TMUX="$SOCK,$(R display -p '#{pid}'),0" TMUX_PANE=%0 "$BROWSER_CLIP" "$@"; }

# script(1) flushes a client's typescript only when the client exits, so read
# the buffer first, then settle() before asking what a client received.
settle() { R kill-server 2>/dev/null; sleep 0.5; }
# tmux writes the request with an empty selection field (ESC ] 52 ; ; data).
osc52_in() { grep -ac "$(printf '\033')]52;[a-z]*;$(printf %s "$2" | base64)" "$SANDBOX/ts.$1" 2>/dev/null || true; }
newest_buffer() { R show-buffer 2>/dev/null; }
pbcopied() { cat "$SANDBOX/pbcopy.out" 2>/dev/null; }
opened() { cat "$SANDBOX/open.out" 2>/dev/null; }

CASE=K1; if want; then
    fresh
    printf '' | T -q 2>/dev/null; ok "K1 empty input fails" 1 "$?"
    ok "K1 empty input copies nothing" "" "$(pbcopied)$(newest_buffer)"
fi

CASE=K2; if want; then
    fresh
    ( unset TMUX; printf 'plain' | "$TOCLIP" -q )
    ok "K2 outside tmux and ssh: pbcopy" "plain" "$(pbcopied)"
fi

CASE=K4; if want; then
    fresh; : > "$SANDBOX/ttys"
    attach local >/dev/null
    TOCLIP_REMOTE_PIDS="" T -q 'at-screen'
    ok "K4 local client only: pbcopy" "at-screen" "$(pbcopied)"
    ok "K4 local client only: buffer kept" "at-screen" "$(newest_buffer)"
fi

CASE=K5; if want; then
    # Both screens show the session and the mini's client attached last, but
    # the keypress came from the laptop.
    fresh; : > "$SANDBOX/ttys"
    remote=$(attach remote)
    attach local >/dev/null
    typed "$remote"
    TOCLIP_REMOTE_PIDS="$remote" T -q 'to-laptop'
    ok "K5 buffer kept for frommini" "to-laptop" "$(newest_buffer)"
    ok "K5 not the mini's pbcopy" "" "$(pbcopied)"
    settle
    ok "K5 OSC 52 reaches the ssh client" 1 "$(osc52_in remote to-laptop)"
    ok "K5 not the local client" 0 "$(osc52_in local to-laptop)"
fi

CASE=K6; if want; then
    fresh; : > "$SANDBOX/ttys"
    remote=$(attach remote)
    TOCLIP_OSC52_MAX=4 TOCLIP_REMOTE_PIDS="$remote" T -q 'too-big'
    ok "K6 oversize fails" 1 "$?"
    ok "K6 oversize buffer kept" "too-big" "$(newest_buffer)"
    settle
    ok "K6 oversize not emitted" 0 "$(osc52_in remote too-big)"
fi

CASE=K7; if want; then
    # Bytes survive: multibyte text and trailing newlines.
    fresh
    printf 'héllo 中文\n\n' | T -q
    ok "K7 bytes preserved" "$(printf 'héllo 中文\n\n' | shasum)" "$(shasum < "$SANDBOX/pbcopy.out")"
fi

CASE=K9; if want; then
    # --remote answers where a copy would go and copies nothing.
    fresh; : > "$SANDBOX/ttys"
    local_pid=$(attach local)
    TOCLIP_REMOTE_PIDS="" T --remote; ok "K9 local client only: not remote" 1 "$?"
    remote=$(attach remote)
    typed "$remote"
    TOCLIP_REMOTE_PIDS="$remote" T --remote; ok "K9 ssh client typed at last: remote" 0 "$?"
    typed "$local_pid"
    TOCLIP_REMOTE_PIDS="$remote" T --remote; ok "K9 local client typed at last: not remote" 1 "$?"
    ( unset TMUX; "$TOCLIP" --remote ); ok "K9 outside tmux and ssh: not remote" 1 "$?"
    ( unset TMUX; SSH_CONNECTION='10.0.0.1 1 10.0.0.2 22' "$TOCLIP" --remote ); ok "K9 outside tmux over ssh: remote" 0 "$?"
    ok "K9 nothing copied" "" "$(pbcopied)$(newest_buffer)"
fi

CASE=K10; if want; then
    # The pane's environment says ssh (its server was started over ssh), but
    # the only client now is at the mini's screen, so the URL opens there.
    fresh; : > "$SANDBOX/ttys"
    attach local >/dev/null
    SSH_CONNECTION='10.0.0.1 1 10.0.0.2 22' TOCLIP_REMOTE_PIDS="" B 'https://github.com/o/r'
    ok "K10 local client only: opened here" "https://github.com/o/r" "$(opened)"
    ok "K10 local client only: nothing copied" "" "$(pbcopied)$(newest_buffer)"
fi

CASE=K11; if want; then
    fresh; : > "$SANDBOX/ttys"
    remote=$(attach remote)
    attach local >/dev/null
    typed "$remote"
    TOCLIP_REMOTE_PIDS="$remote" B 'https://github.com/o/r/pull/1'
    ok "K11 ssh client: not opened on the mini" "" "$(opened)"
    ok "K11 ssh client: buffer kept" "https://github.com/o/r/pull/1" "$(newest_buffer)"
    settle
    ok "K11 OSC 52 reaches the ssh client" 1 "$(osc52_in remote https://github.com/o/r/pull/1)"
fi

CASE=K12; if want; then
    fresh
    ( unset TMUX; "$BROWSER_CLIP" 'https://github.com/o/r/tree/main' )
    ok "K12 outside tmux and ssh: opened here" "https://github.com/o/r/tree/main" "$(opened)"
    "$BROWSER_CLIP"; ok "K12 no URL fails" 1 "$?"
fi

CASE=K13; if want; then
    # The laptop's ssh client is still attached, idle, while the keypress comes
    # from the mini's own screen: the copy stays on the mini.
    fresh; : > "$SANDBOX/ttys"
    local_pid=$(attach local)
    remote=$(attach remote)
    typed "$local_pid"
    TOCLIP_REMOTE_PIDS="$remote" T -q 'at-desk'
    ok "K13 idle ssh client: pbcopy" "at-desk" "$(pbcopied)"
    ok "K13 idle ssh client: buffer kept" "at-desk" "$(newest_buffer)"
    settle
    ok "K13 nothing sent to the ssh client" 0 "$(osc52_in remote at-desk)"
fi

CASE=K14; if want; then
    fresh; : > "$SANDBOX/ttys"
    local_pid=$(attach local)
    remote=$(attach remote)
    typed "$local_pid"
    TOCLIP_REMOTE_PIDS="$remote" B 'https://github.com/o/r/issues/2'
    ok "K14 idle ssh client: opened here" "https://github.com/o/r/issues/2" "$(opened)"
    ok "K14 idle ssh client: nothing copied" "" "$(pbcopied)$(newest_buffer)"
fi

CASE=K8; if want; then
    ok "K8 real clipboard untouched" "$REAL_CLIP_BEFORE" "$(pbpaste | shasum)"
fi

printf '\n%d passed, %d failed%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
