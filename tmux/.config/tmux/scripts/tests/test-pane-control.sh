#!/usr/bin/env bash
# test-pane-control.sh — the pinned traps for pane mode + floating zoom.
#
# Each case exists because something specific can silently go wrong; the
# comment on each says what. Runs entirely on throwaway sockets — it never
# touches a live tmux server. Usage: bash test-pane-control.sh [T1 T5 ...]

set -uo pipefail

SOCK="pctest-$$"
OUTER="pcouter-$$"
CONF="$HOME/.config/tmux/tmux.conf"
FLOAT="$HOME/.config/tmux/scripts/tmux-float-pane.sh"
RELOC="$HOME/.config/tmux/scripts/tmux-pane-relocate.sh"

PASS=0; FAIL=0; FAILED=""

T() { tmux -L "$SOCK" "$@"; }
O() { tmux -L "$OUTER" "$@"; }

cleanup() { T kill-server 2>/dev/null; O kill-server 2>/dev/null; }
trap cleanup EXIT

fresh() {
    T kill-server 2>/dev/null; sleep 0.2
    T -f "$CONF" new-session -d -s t -x 200 -y 50 2>/dev/null
    sleep 0.5
    SOCKPATH=$(T display -p '#{socket_path}')
}

# Run a script against THE TEST SERVER. The scripts resolve tmux through $TMUX
# (in real use they are invoked by run-shell, which sets it). Without this they
# fall through to the DEFAULT socket — i.e. the user's live server — where the
# test's pane ids do not exist, so every call silently no-ops and the
# assertions pass for the wrong reason. That false-green cost a debugging pass.
# FLOAT_GRACE_SECS is shortened so recovery cases do not have to sit out the
# production grace window; the grace itself is exercised by T1 needing the
# holder to age past it before the sweep will touch it.
R() { TMUX="$SOCKPATH,0,0" FLOAT_GRACE_SECS=1 bash "$@"; }
tiled() { T list-panes -t "$1" -f '#{==:#{pane_floating_flag},0}' -F '#{pane_id}' 2>/dev/null | tr '\n' ' '; }
layout() { T display-message -p -t "$1" '#{window_layout}' 2>/dev/null; }

ok()   { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); FAILED="$FAILED $2"; printf '  \033[31mFAIL\033[0m %s\n       %s\n' "$1" "$2"; }
check(){ [ "$2" = "$3" ] && ok "$1" || no "$1" "expected [$3] got [$2]"; }

want() { case " ${WANT:-} " in *" $1 "*) return 0;; esac; [ -z "${WANT:-}" ]; }

# ---------------------------------------------------------------------------
# T5 — identity round trip. select-layout restores geometry but NOT identity;
# a naive float round trip returns %0 %1 %2 as %0 %2 %1.
# ---------------------------------------------------------------------------
t5() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; T split-window -v -t "$W"; sleep 0.3
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    R "$FLOAT" toggle "$P" >/dev/null 2>&1 &   # container blocks; run detached
    sleep 2
    # assert the float ACTUALLY happened — otherwise "restored exactly" is
    # trivially true and the case is a false green
    check "T5 pane left the window while floated" \
        "$(tiled "$W" | grep -c "$P" || true)" "0"
    R "$FLOAT" restore "$P" >/dev/null 2>&1
    sleep 0.5
    check "T5 pane order restored exactly"  "$(tiled "$W")" "$before_o"
    check "T5 layout restored exactly"      "$(layout "$W")" "$before_l"
}

# ---------------------------------------------------------------------------
# T1 — crash restore. The container's shell normally calls restore; a SIGKILL
# skips it. The sweep must bring the pane home.
# ---------------------------------------------------------------------------
t1() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    before=$(tiled "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    R "$FLOAT" toggle "$P" >/dev/null 2>&1 &
    sleep 2
    holders=$(T list-sessions -F '#{session_name}' | grep -c '^_float_' || true)
    [ "$holders" -ge 1 ] && ok "T1 pane is in a holder while floated" \
        || no "T1 pane is in a holder while floated" "no _float_ session found"
    pkill -9 -f "tmux-float-pane.sh container" 2>/dev/null
    sleep 0.5
    R "$FLOAT" sweep >/dev/null 2>&1
    sleep 0.5
    check "T1 sweep restores after a killed container" "$(tiled "$W")" "$before"
    check "T1 holder cleaned up" "$(T list-sessions -F '#{session_name}' | grep -c '^_float_' || true)" "0"
}

# ---------------------------------------------------------------------------
# T2 — degraded restore. A pane added to the source window while floated
# invalidates the recorded layout; nothing may be lost or mis-slotted.
# ---------------------------------------------------------------------------
t2() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    R "$FLOAT" toggle "$P" >/dev/null 2>&1 &
    sleep 2
    T split-window -h -t "$W"; sleep 0.3     # source window changed under us
    n_before=$(tiled "$W" | wc -w | tr -d ' ')
    R "$FLOAT" restore "$P" >/dev/null 2>&1
    sleep 0.5
    check "T2 floated pane came back"        "$(tiled "$W" | grep -c "$P" || true)" "1"
    check "T2 no pane lost in degraded path" "$(tiled "$W" | wc -w | tr -d ' ')" "$((n_before+1))"
}

# ---------------------------------------------------------------------------
# T4 — concurrent floats. State lives per-pane, not in globals; two floats in
# different sessions must not collide.
# ---------------------------------------------------------------------------
t4() {
    fresh
    W1=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W1"; sleep 0.2
    T new-session -d -s t2 -x 200 -y 50; sleep 0.2
    W2=$(T display -p -t t2 '#{window_id}')
    T split-window -v -t "$W2"; sleep 0.3
    b1=$(tiled "$W1"); b2=$(tiled "$W2")
    P1=$(T display -p -t "$W1" '#{pane_id}'); P2=$(T display -p -t "$W2" '#{pane_id}')
    R "$FLOAT" toggle "$P1" >/dev/null 2>&1 &
    R "$FLOAT" toggle "$P2" >/dev/null 2>&1 &
    sleep 2.5
    check "T4 two holders exist at once" \
        "$(T list-sessions -F '#{session_name}' | grep -c '^_float_' || true)" "2"
    R "$FLOAT" restore "$P1" >/dev/null 2>&1
    R "$FLOAT" restore "$P2" >/dev/null 2>&1
    sleep 0.5
    check "T4 session 1 restored to its own window" "$(tiled "$W1")" "$b1"
    check "T4 session 2 restored to its own window" "$(tiled "$W2")" "$b2"
}

# ---------------------------------------------------------------------------
# T3 — resurrect save must never capture a float.
# ---------------------------------------------------------------------------
t3() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    R "$FLOAT" toggle "$P" >/dev/null 2>&1 &
    sleep 2
    # prepare-save is what the wrapper runs before handing off to resurrect
    R "$FLOAT" prepare-save >/dev/null 2>&1
    sleep 0.5
    check "T3 no holder survives prepare-save" \
        "$(T list-sessions -F '#{session_name}' | grep -c '^_float_' || true)" "0"
    check "T3 pane is back before the snapshot" "$(tiled "$W" | grep -c "$P" || true)" "1"
}

# ---------------------------------------------------------------------------
# T6 — the wrap trap. {left-of} from the leftmost pane resolves to the
# RIGHTMOST one, so an unguarded push at an edge swaps the wrong panes.
# ---------------------------------------------------------------------------
t6() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; sleep 0.3
    left=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    right=$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)
    T select-pane -t "$left"
    before=$(tiled "$W")
    R "$RELOC" push left "$left" >/dev/null 2>&1
    sleep 0.4
    check "T6 push left at the left edge does not swap with the rightmost" \
        "$(tiled "$W")" "$before"
    # and the genuine swap still works from the right pane
    T select-pane -t "$right"
    R "$RELOC" push left "$right" >/dev/null 2>&1
    sleep 0.4
    check "T6 push left from the right pane does swap" "$(tiled "$W")" "$right $left "
}

# ---------------------------------------------------------------------------
# T7 — no-op when already the full-span edge; re-running the relocation would
# churn pane order for no visible change.
# ---------------------------------------------------------------------------
t7() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; sleep 0.3
    left=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    R "$RELOC" push left "$left" >/dev/null 2>&1   # already full-height left
    sleep 0.4
    check "T7 already-full-span edge is a no-op (order)"  "$(tiled "$W")"  "$before_o"
    check "T7 already-full-span edge is a no-op (layout)" "$(layout "$W")" "$before_l"
}

# ---------------------------------------------------------------------------
# T7b — the headline move: bottom pane of a vertical split pushed right must
# become the full-height right column.
# ---------------------------------------------------------------------------
t7b() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    bottom=$(T display -p -t "$W" '#{pane_id}')
    R "$RELOC" push right "$bottom" >/dev/null 2>&1
    sleep 0.4
    h=$(T display-message -p -t "$bottom" '#{pane_height}')
    atr=$(T display-message -p -t "$bottom" '#{pane_at_right}')
    att=$(T display-message -p -t "$bottom" '#{pane_at_top}')
    check "T7b bottom pane pushed right becomes full-height right column" \
        "$atr$att$([ "$h" -ge 45 ] && echo tall)" "11tall"
}

# ---------------------------------------------------------------------------
# T8 — marked-pane inversion. join/move-pane with -s omitted uses the MARKED
# pane as source, i.e. the exact opposite move.
# ---------------------------------------------------------------------------
t8() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.2
    T new-window -t t; sleep 0.3
    W2=$(T display -p -t t '#{window_id}')
    target=$(T list-panes -t "$W2" -F '#{pane_id}' | head -1)
    mover=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    T select-pane -t "$target" -m            # mark a pane in the OTHER window
    R "$RELOC" marked "$mover" >/dev/null 2>&1
    sleep 0.5
    moved_in_w2=$(T list-panes -t "$W2" -F '#{pane_id}' | grep -c "$mover" || true)
    target_stayed=$(T list-panes -t "$W2" -F '#{pane_id}' | grep -c "$target" || true)
    check "T8 the CURRENT pane moved to the mark (not the reverse)" \
        "$moved_in_w2$target_stayed" "11"
}

# ---------------------------------------------------------------------------
# T9/T10/T11 — key surface. Needs a real client, so an outer tmux provides the
# pty. T10: any key (bound or not) drops the client out of a custom table.
# ---------------------------------------------------------------------------
t10() {
    fresh
    O kill-server 2>/dev/null; sleep 0.2
    O -f /dev/null new-session -d -s o -x 200 -y 50
    O send-keys -t o "TMUX= tmux -L $SOCK -f '$CONF' attach -t t" Enter
    sleep 2.5
    C=$(T list-clients -F '#{client_name}' 2>/dev/null | head -1)
    if [ -z "$C" ]; then no "T10 client attached" "no client"; return; fi

    T switch-client -c "$C" -T panes; sleep 0.4
    check "T10 entered the panes table" "$(T display -p -t "$C" '#{client_key_table}')" "panes"

    O send-keys -t o g; sleep 0.8          # 'g' is unbound in the panes table
    check "T10 an unbound key exits the mode (cannot trap)" \
        "$(T display -p -t "$C" '#{client_key_table}')" "root"

    T switch-client -c "$C" -T panes; sleep 0.3
    O send-keys -t o Escape; sleep 0.8
    check "T10 Escape exits the mode" \
        "$(T display -p -t "$C" '#{client_key_table}')" "root"
}

# T9 — inside a float the holder's restricted key table must be in force, so
# this config's destructive prefix verbs are simply not reachable.
t9() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    R "$FLOAT" toggle "$P" >/dev/null 2>&1 &
    sleep 2
    holder=$(T list-sessions -F '#{session_name}' | grep '^_float_' | head -1)
    if [ -z "$holder" ]; then no "T9 holder exists" "none"; R "$FLOAT" restore "$P" >/dev/null 2>&1; return; fi
    # NB: bare name, not "=$holder" — show-option's target is a target-pane and
    # the `=` exact-session form reads back empty with rc=0 there.
    check "T9 holder uses the restricted root table" \
        "$(T show -qv -t "$holder" key-table)" "float-root"
    check "T9 holder is marked as ours" \
        "$([ -n "$(T show -qv -t "$holder" @fl_holder_nonce)" ] && echo yes)" "yes"
    check "T9 float-root exposes only the prefix routes" \
        "$(T list-keys -T float-root | wc -l | tr -d ' ')" "2"
    check "T9 float-prefix exposes only z/d/[" \
        "$(T list-keys -T float-prefix | wc -l | tr -d ' ')" "3"
    R "$FLOAT" restore "$P" >/dev/null 2>&1; sleep 0.4
}

# ---------------------------------------------------------------------------
# T12 — 3.7b smoke against the real config.
# ---------------------------------------------------------------------------
t12() {
    fresh
    check "T12 message-style fills the row (3.7 needs fill=)" \
        "$(T show -gv message-style | grep -c 'fill=')" "1"
    check "T12 status-format[1] is ours not 3.7's pane list" \
        "$(T show -gv 'status-format[1]' | grep -c 'client_key_table')" "1"
    check "T12 resurrect save routed through the wrapper" \
        "$(T show -gv @resurrect-save-script-path | grep -c 'tmux-resurrect-save.sh')" "1"
    check "T12 prefix p is bound (not clobbered by a later unbind)" \
        "$(T list-keys -T prefix | awk '$3=="prefix"&&$4=="p"{print "yes";exit}')" "yes"
    check "T12 stock new-pane still on prefix *" \
        "$(T list-keys -T prefix | awk '$3=="prefix"&&$4=="*"{print $NF;exit}')" "new-pane"
}

# T13 — a native floating pane must not corrupt counts or snapshots.
t13() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.2
    T new-pane -t "$W" 2>/dev/null; sleep 0.5
    check "T13 window_panes counts the native float (why we filter)" \
        "$(T display -p -t "$W" '#{window_panes}')" "3"
    check "T13 our tiled filter ignores it" "$(tiled "$W" | wc -w | tr -d ' ')" "2"
    fl=$(T list-panes -t "$W" -f '#{==:#{pane_floating_flag},1}' -F '#{pane_id}')
    R "$RELOC" push left "$fl" >/dev/null 2>&1; sleep 0.3
    check "T13 push refuses a floating pane" \
        "$(T display -p -t "$fl" '#{pane_floating_flag}')" "1"
}

# ---------------------------------------------------------------------------
# T11 — mode bracketing. Verbs that change where you are must NOT re-enter the
# sticky table: break moves you to another window, and float opens a blocking
# container whose nested client must not inherit a pending table.
# ---------------------------------------------------------------------------
t11() {
    fresh
    zbind=$(T list-keys -T panes | awk '$4=="z"')
    bbind=$(T list-keys -T panes | awk '$4=="b"')
    hbind=$(T list-keys -T panes | awk '$4=="h"')
    check "T11 float does not re-enter the mode" \
        "$(printf '%s' "$zbind" | grep -c 'switch-client -T panes' || true)" "0"
    check "T11 break does not re-enter the mode" \
        "$(printf '%s' "$bbind" | grep -c 'switch-client -T panes' || true)" "0"
    check "T11 push DOES re-enter the mode (sticky)" \
        "$(printf '%s' "$hbind" | grep -c 'switch-client -T panes' || true)" "1"
}

# ---------------------------------------------------------------------------
# T14 — THE END-TO-END PATH. Everything above drives toggle/restore directly,
# which never exercises the container: display-popup needs a client, and with
# none attached it fails after the break has already happened. This drives the
# real key, through a real pty, and closes it with the real in-float key.
# ---------------------------------------------------------------------------
t14() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')

    O kill-server 2>/dev/null; sleep 0.2
    O -f /dev/null new-session -d -s o -x 200 -y 50
    O send-keys -t o "TMUX= tmux -L $SOCK -f '$CONF' attach -t t" Enter
    sleep 2.5
    C=$(T list-clients -F '#{client_name}' 2>/dev/null | head -1)
    if [ -z "$C" ]; then no "T14 client attached" "no client"; return; fi
    T select-pane -t "$P"
    # capture AFTER the client attaches: attaching resizes the window, so a
    # baseline taken before it would never match the restored layout
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    before_w=$(T display-message -p -t "$P" '#{pane_width}')

    O send-keys -t o C-b; sleep 0.3; O send-keys -t o z; sleep 3

    check "T14 prefix z floated the pane out of the window" \
        "$(tiled "$W" | grep -c "$P" || true)" "0"
    check "T14 a container client is attached to the holder" \
        "$(T list-clients -F '#{session_name}' | grep -c '^_float_' || true)" "1"
    # the pane must be resized to the container interior. Compare against the
    # pane's own pre-float width, not a hardcoded band — a loose band happily
    # passed while the float was silently not happening at all.
    fw=$(T display-message -p -t "$P" '#{pane_width}' 2>/dev/null)
    cw=$(T display-message -p -t "$C" '#{client_width}' 2>/dev/null)
    check "T14 pane resized to the container (was $before_w, now $fw, client $cw)" \
        "$([ "${fw:-0}" != "${before_w:-0}" ] && [ "${fw:-0}" -lt "${cw:-0}" ] && \
           [ "${fw:-0}" -gt $(( ${cw:-0} * 3 / 4 )) ] && echo yes)" "yes"

    # close it with the in-float key: float-root routes C-b to float-prefix,
    # where z detaches the nested client and the container's shell restores
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o z; sleep 3

    check "T14 prefix z inside the float restored the pane" "$(tiled "$W")" "$before_o"
    check "T14 layout restored after the round trip"        "$(layout "$W")" "$before_l"
    check "T14 holder cleaned up" \
        "$(T list-sessions -F '#{session_name}' | grep -c '^_float_' || true)" "0"
    check "T14 outer client back on its own session" \
        "$(T display -p -t "$C" '#{session_name}' 2>/dev/null)" "t"
}

WANT="${*:-}"
echo "tmux $(tmux -V) — pane control suite"
for c in t12 t13 t5 t1 t2 t4 t3 t6 t7 t7b t8 t9 t10 t11 t14; do
    n=$(echo "$c" | tr 'a-z' 'A-Z')
    want "$n" && { echo "[$n]"; $c; }
done
echo
printf 'passed %d, failed %d%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED)}"
[ "$FAIL" -eq 0 ]
