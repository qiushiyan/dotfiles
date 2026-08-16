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

# Everything this suite writes goes under one temp root, removed on exit.
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/pane-control-test.XXXXXX")
SANDBOX_RESURRECT="$SANDBOX/resurrect"
mkdir -p "$SANDBOX_RESURRECT"

# The real save directory — asserted untouched by T21, never written to. Mirror
# resurrect's own selection: it prefers the legacy ~/.tmux/resurrect whenever
# that directory exists and only falls back to XDG. Hardcoding XDG would make the
# isolation guard watch a directory the plugin isn't using, and pass on a machine
# with the legacy layout while the real one was being written.
if [ -d "$HOME/.tmux/resurrect" ]; then
    REAL_RESURRECT="$HOME/.tmux/resurrect"
else
    REAL_RESURRECT="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
fi

cleanup() {
    T kill-server 2>/dev/null; O kill-server 2>/dev/null
    [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
}
trap cleanup EXIT

fresh() {
    T kill-server 2>/dev/null; sleep 0.2
    T -f "$CONF" new-session -d -s t -x 200 -y 50 2>/dev/null
    sleep 0.5
    SOCKPATH=$(T display -p '#{socket_path}')
    # REDIRECT RESURRECT. resurrect resolves its save directory from
    # @resurrect-dir on whichever server it is inspecting, but the DEFAULT is a
    # single shared path — so a test that reaches the real save.sh writes a
    # snapshot of a throwaway server into the user's save dir and repoints
    # `last` at it. That happened: a two-pane test server became the newest
    # save, and the next restore would have brought back test junk instead of
    # the user's real sessions. Point every test server somewhere disposable.
    T set -g @resurrect-dir "$SANDBOX_RESURRECT" 2>/dev/null
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

# Float WITHOUT presenting it — the state a container that died instantly would
# leave. The recovery cases are about exactly that window, and a real toggle now
# (correctly) rolls back when presentation fails, so it cannot be observed via R.
RS() { TMUX="$SOCKPATH,0,0" FLOAT_GRACE_SECS=1 FLOAT_SKIP_CONTAINER=1 bash "$@"; }
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
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1 &   # container blocks; run detached
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
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1 &
    sleep 2
    holders=$(T list-sessions -F '#{session_name}' | grep -c '^_float_' || true)
    [ "$holders" -ge 1 ] && ok "T1 pane is in a holder while floated" \
        || no "T1 pane is in a holder while floated" "no _float_ session found"
    # Kill ONLY this test's container. An unscoped `pkill -f
    # "tmux-float-pane.sh container"` matches every such process on the machine
    # — including one serving the user's real tmux server — so match on this
    # test's own socket path, which the container's argv carries.
    for pid in $(pgrep -f "tmux-float-pane.sh container" 2>/dev/null); do
        if ps -o command= -p "$pid" 2>/dev/null | grep -qF "$SOCKPATH"; then
            kill -9 "$pid" 2>/dev/null
        fi
    done
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
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1 &
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
    RS "$FLOAT" toggle "$P1" >/dev/null 2>&1 &
    RS "$FLOAT" toggle "$P2" >/dev/null 2>&1 &
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
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1 &
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
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1 &
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

# ---------------------------------------------------------------------------
# T15 — two restorers must not corrupt the pane order. prepare_save reaches
# this directly: it detaches the container (waking the container's own restore)
# and then calls restore itself.
# ---------------------------------------------------------------------------
t15() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; T split-window -v -t "$W"; sleep 0.3
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1 &
    sleep 2
    R "$FLOAT" restore "$P" >/dev/null 2>&1 &
    R "$FLOAT" restore "$P" >/dev/null 2>&1 &
    wait 2>/dev/null; sleep 0.6
    check "T15 concurrent restores keep pane order" "$(tiled "$W")" "$before_o"
    check "T15 concurrent restores keep layout"     "$(layout "$W")" "$before_l"
}

# ---------------------------------------------------------------------------
# T16 — a marked holder must never hold a live pane without enough state to
# recover it. Reproduces the window between break-pane and publishing @fl_*.
# ---------------------------------------------------------------------------
t16() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    # hand-build the intermediate state: marked holder, pane moved in, no @fl_*
    T new-session -d -s _float_partial
    T set -t _float_partial @fl_holder_nonce "partial"
    PLACE=$(T display -p -t _float_partial '#{window_id}')
    T break-pane -d -s "$P" -t '_float_partial:'; T kill-window -t "$PLACE"
    sleep 0.3
    R "$FLOAT" sweep >/dev/null 2>&1; sleep 1.5
    reachable=$(T list-panes -a -F '#{pane_id}' | grep -c "$P" || true)
    hidden=$(T list-sessions -F '#{session_name}' | grep -c '^_float_' || true)
    check "T16 pane from a metadata-less holder is not lost" "$reachable" "1"
    check "T16 it is surfaced, not left in an internal holder" "$hidden" "0"
}

# ---------------------------------------------------------------------------
# T17 — normalization must fail closed: if a float survives, prepare-save
# reports failure and the wrapper must NOT hand off to the real save.
# ---------------------------------------------------------------------------
t17() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    # a holder that cannot be restored: source window killed, session gone too
    T new-session -d -s _float_stuck
    T set -t _float_stuck @fl_holder_nonce stuck
    PLACE=$(T display -p -t _float_stuck '#{window_id}')
    T break-pane -d -s "$P" -t '_float_stuck:'; T kill-window -t "$PLACE"
    T set -p -t "$P" @fl_phase floating
    T set -p -t "$P" @fl_holder _float_stuck
    T set -p -t "$P" @fl_src_sess "gone-session"
    T set -p -t "$P" @fl_src_win  "@999"
    sleep 0.3
    R "$FLOAT" prepare-save >/dev/null 2>&1; rc=$?
    # After a successful surface-to-recovery there is no marked holder left, so
    # prepare-save may legitimately succeed; what must never happen is success
    # while a marked holder still holds the pane. Count holders with tmux
    # directly — an earlier version asked the script for a verb it doesn't have,
    # which printed usage, counted zero, and passed for the wrong reason.
    left=$(T list-sessions -F '#{session_name}' 2>/dev/null | grep -c '^_float_' || true)
    check "T17 prepare-save never reports success with a holder surviving" \
        "$([ "$rc" -ne 0 ] || [ "$left" = 0 ] && echo ok)" "ok"

    # and the wrapper must abort rather than exec the real save
    # The fake save must actually be reachable, or "aborted" proves nothing —
    # the wrapper honours RESURRECT_SAVE for exactly this. Guard that the seam
    # exists, so this can't silently go back to invoking the real save.
    check "T17 wrapper honours the RESURRECT_SAVE seam" \
        "$(grep -c 'RESURRECT_SAVE' "$HOME/.config/tmux/scripts/tmux-resurrect-save.sh")" "1"
    marker="$SANDBOX/real-save-ran"; rm -f "$marker"
    printf '#!/bin/sh\ntouch %s\n' "$marker" > "$SANDBOX/fake-save.sh"
    chmod +x "$SANDBOX/fake-save.sh"
    # A float that genuinely cannot be normalised: another restorer holds a
    # FRESH claim, so restore defers to it and prepare-save times out. (An
    # unreachable source window is NOT stuck — recovery surfaces it into a
    # visible session, after which saving is correct and must proceed.)
    T new-session -d -s _float_stuck2
    T set -t _float_stuck2 @fl_holder_nonce stuck2
    P2=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    PL2=$(T display -p -t _float_stuck2 '#{window_id}')
    T break-pane -d -s "$P2" -t '_float_stuck2:'; T kill-window -t "$PL2"
    T set -p -t "$P2" @fl_phase floating
    T set -p -t "$P2" @fl_holder _float_stuck2
    T set -p -t "$P2" @fl_src_sess "gone"; T set -p -t "$P2" @fl_src_win "@998"
    T set -p -t "$P2" @fl_claim "99999:$(date +%s)"
    TMUX="$SOCKPATH,0,0" FLOAT_GRACE_SECS=1 RESURRECT_SAVE="$SANDBOX/fake-save.sh" \
        bash "$HOME/.config/tmux/scripts/tmux-resurrect-save.sh" quiet >/dev/null 2>&1
    check "T17 wrapper does not run the real save when a float is stuck" \
        "$([ -e "$marker" ] && echo ran || echo aborted)" "aborted"
    rm -f "$SANDBOX/fake-save.sh" "$marker"
}

# ---------------------------------------------------------------------------
# T18 — undo. Completely uncovered before this review.
# ---------------------------------------------------------------------------
t18() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; sleep 0.3
    before_o=$(tiled "$W")
    right=$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)
    R "$RELOC" push left "$right" >/dev/null 2>&1; sleep 0.4
    swapped=$(tiled "$W")
    check "T18 push swapped"                "$([ "$swapped" != "$before_o" ] && echo yes)" "yes"
    R "$RELOC" undo "$W" >/dev/null 2>&1; sleep 0.4
    check "T18 undo restores the pane order" "$(tiled "$W")" "$before_o"

    # edge relocation undo
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    before_l=$(layout "$W"); bottom=$(T display -p -t "$W" '#{pane_id}')
    R "$RELOC" push right "$bottom" >/dev/null 2>&1; sleep 0.4
    R "$RELOC" undo "$W" >/dev/null 2>&1; sleep 0.4
    check "T18 undo restores an edge relocation" "$(layout "$W")" "$before_l"
}

# T18b — rapid pushes in the sticky mode must not lose journal entries. This
# has to be CLIENT-driven: the serialization being tested is tmux's command
# queue, which only applies to keys going through bindings. Invoking the script
# twice in parallel from a shell bypasses the queue entirely and tests a path
# no user can reach.
t18b() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; sleep 0.3
    O kill-server 2>/dev/null; sleep 0.2
    O -f /dev/null new-session -d -s o -x 200 -y 50
    O send-keys -t o "TMUX= tmux -L $SOCK -f '$CONF' attach -t t" Enter
    sleep 2.5
    C=$(T list-clients -F '#{client_name}' 2>/dev/null | head -1)
    if [ -z "$C" ]; then no "T18b client attached" "no client"; return; fi
    T select-pane -t "$(T list-panes -t "$W" -F '#{pane_id}' | head -1)"
    o0=$(tiled "$W")

    O send-keys -t o C-b; sleep 0.3; O send-keys -t o p; sleep 0.5
    # two mutating pushes back to back, no pause between them
    O send-keys -t o l; O send-keys -t o h; sleep 1.5

    recs=$(T show -wqv -t "$W" @pane_journal | grep -c . || true)
    check "T18b both rapid pushes recorded a journal entry" "$recs" "2"
    R "$RELOC" undo "$W" >/dev/null 2>&1; sleep 0.3
    R "$RELOC" undo "$W" >/dev/null 2>&1; sleep 0.3
    check "T18b undoing both returns the original order" "$(tiled "$W")" "$o0"
}

# T18c — a stale journal record must be refused, not half-applied.
t18c() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; sleep 0.3
    right=$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)
    R "$RELOC" push left "$right" >/dev/null 2>&1; sleep 0.4
    after_push=$(tiled "$W")
    T split-window -v -t "$W"; sleep 0.4      # pane set changed since the record
    before_undo=$(tiled "$W")
    R "$RELOC" undo "$W" >/dev/null 2>&1; sleep 0.4
    check "T18c stale record is refused (no partial mutation)" \
        "$(tiled "$W")" "$before_undo"
    check "T18c refused record is retained" \
        "$(T show -wqv -t "$W" @pane_journal | grep -c . || true)" "1"
}

# T19 — a surfaced recovery session must be usable: the prefix keys the holder
# disabled have to come back, or the user's C-a is dead in it.
t19() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1 &
    sleep 2
    T kill-window -t "$W" 2>/dev/null       # destroy the source
    T kill-session -t t 2>/dev/null
    sleep 0.3
    R "$FLOAT" restore "$P" >/dev/null 2>&1; sleep 0.8
    rs=$(T list-sessions -F '#{session_name}' | grep '^recovered-' | head -1)
    if [ -z "$rs" ]; then no "T19 recovery session created" "none"; return; fi
    # -A folds in the inherited global; without it an unset (correct) session
    # option reads back empty and looks like a failure.
    check "T19 recovered session restores prefix"  "$(T show -Aqv -t "$rs" prefix)"  "C-b"
    check "T19 recovered session restores prefix2" "$(T show -Aqv -t "$rs" prefix2)" "C-a"
    check "T19 recovered session has a normal key table" \
        "$(T show -Aqv -t "$rs" key-table)" "root"
}

# ---------------------------------------------------------------------------
# T20 — the float's frame, asserted on what the client actually DREW. The outer
# pane's capture is the inner client's rendering, popup border glyphs included,
# so this is the one case that checks something visual rather than tmux state.
# ---------------------------------------------------------------------------
t20() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    T select-pane -t "$P" -T "notes"          # a named pane, to check the title
    O kill-server 2>/dev/null; sleep 0.2
    O -f /dev/null new-session -d -s o -x 120 -y 36
    O send-keys -t o "TMUX= tmux -L $SOCK -f '$CONF' attach -t t" Enter
    sleep 2.5
    C=$(T list-clients -F '#{client_name}' 2>/dev/null | head -1)
    if [ -z "$C" ]; then no "T20 client attached" "no client"; return; fi
    T select-pane -t "$P"
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o z; sleep 3

    cap=$(O capture-pane -p -t o)
    check "T20 float draws a heavy border" \
        "$(printf '%s' "$cap" | grep -cm1 '[┏┓┗┛━┃]' || true)" "1"
    check "T20 float does not draw the global rounded border" \
        "$(printf '%s' "$cap" | grep -cm1 '[╭╮╰╯]' || true)" "0"
    check "T20 title names the pane, not the holder nonce" \
        "$(printf '%s' "$cap" | grep -cm1 'notes' || true)" "1"

    # and the other popups in this config keep the global rounded frame
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o z; sleep 2
    check "T20 global popup-border-lines untouched" \
        "$(T show -gv popup-border-lines)" "rounded"
}

# ---------------------------------------------------------------------------
# T21 — the suite must never write into the user's real resurrect directory.
# Regression test for a real incident: an earlier version of T17 invoked the
# real save.sh, which wrote a snapshot of a throwaway two-pane server into
# ~/.local/share/tmux/resurrect and repointed `last` at it. Restoring after
# that would have produced test junk instead of the user's sessions.
# This case deliberately runs the REAL save path — no RESURRECT_SAVE fake — so
# it proves the redirection holds where it actually matters.
# ---------------------------------------------------------------------------
t21() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3

    check "T21 test server points at the sandbox" \
        "$(T show -gv @resurrect-dir)" "$SANDBOX_RESURRECT"

    local before_last before_count after_last after_count sandbox_before sandbox_after
    before_last=$(readlink "$REAL_RESURRECT/last" 2>/dev/null || echo none)
    before_count=$(ls -1 "$REAL_RESURRECT" 2>/dev/null | wc -l | tr -d ' ')
    sandbox_before=$(ls -1 "$SANDBOX_RESURRECT" 2>/dev/null | wc -l | tr -d ' ')

    R "$HOME/.config/tmux/scripts/tmux-resurrect-save.sh" quiet >/dev/null 2>&1
    sleep 1

    sandbox_after=$(ls -1 "$SANDBOX_RESURRECT" 2>/dev/null | wc -l | tr -d ' ')
    after_last=$(readlink "$REAL_RESURRECT/last" 2>/dev/null || echo none)
    after_count=$(ls -1 "$REAL_RESURRECT" 2>/dev/null | wc -l | tr -d ' ')

    check "T21 the save landed in the sandbox" \
        "$([ "$sandbox_after" -gt "$sandbox_before" ] && echo yes)" "yes"
    check "T21 the real save dir gained no files" "$after_count" "$before_count"
    check "T21 the real 'last' pointer is untouched" "$after_last" "$before_last"
}

# ---------------------------------------------------------------------------
# T22 — the STALE-claim path must be as serialized as the fresh one. A fresh
# claim uses set-option -o (atomic), but expiring one and overwriting it is a
# plain write: every contender that sees the same expired claim takes it and
# proceeds, putting two restorers back on the corruption path T15 closed.
# ---------------------------------------------------------------------------
t22() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; T split-window -v -t "$W"; sleep 0.3
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1 &
    sleep 2
    # age the claim past the TTL so both restorers take the steal branch
    T set -p -t "$P" @fl_claim "99999:1"
    R "$FLOAT" restore "$P" >/dev/null 2>&1 &
    R "$FLOAT" restore "$P" >/dev/null 2>&1 &
    wait 2>/dev/null; sleep 0.8
    check "T22 stale-claim contention keeps pane order" "$(tiled "$W")" "$before_o"
    check "T22 stale-claim contention keeps layout"     "$(layout "$W")" "$before_l"
}

# ---------------------------------------------------------------------------
# T23 — a float interrupted DURING publication, before the pane has moved.
# The pane is still in its own window, so nothing in a holder enumerates it;
# if a phase is set with no metadata the pane is wedged — `toggle` treats any
# phase as "already floated" and no-ops forever.
# ---------------------------------------------------------------------------
t23() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    before_o=$(tiled "$W")
    P=$(T display -p -t "$W" '#{pane_id}')

    # hand-build the interrupted state: holder created and marked, phase set,
    # pane never moved
    # exactly what float_pane leaves behind if it dies right after the phase
    # write: holder made and marked with the pane it is for, pane linked back
    # and carrying the phase, but break-pane never ran
    T new-session -d -s _float_interrupted
    T set -t _float_interrupted @fl_holder_nonce "interrupted"
    T set -t _float_interrupted @fl_pane "$P"
    T set -p -t "$P" @fl_phase preparing
    T set -p -t "$P" @fl_holder _float_interrupted
    sleep 0.3

    R "$FLOAT" sweep >/dev/null 2>&1; sleep 1.5

    check "T23 pane never left its window"     "$(tiled "$W")" "$before_o"
    check "T23 rollback cleared the stuck phase" \
        "$(T show -pqv -t "$P" @fl_phase)" ""
    check "T23 no junk recovery session"       \
        "$(T list-sessions -F '#{session_name}' | grep -c '^recovered-\|^_float_' || true)" "0"

    # and the pane must still be floatable afterwards
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1 &
    sleep 2
    check "T23 float works again after rollback" \
        "$(tiled "$W" | grep -c "$P" || true)" "0"
    R "$FLOAT" restore "$P" >/dev/null 2>&1; sleep 0.5
}

# T24 — a container that fails to open must not strand the pane outside its
# window. An invalid @float_border makes display-popup fail.
t24() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    before_o=$(tiled "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    T set -g @float_border "definitely-invalid"
    R "$FLOAT" toggle "$P" >/dev/null 2>&1
    sleep 2
    check "T24 failed container leaves the pane at home" "$(tiled "$W")" "$before_o"
    check "T24 failed container leaves no holder" \
        "$(T list-sessions -F '#{session_name}' | grep -c '^_float_' || true)" "0"
    check "T24 failed container leaves no stuck phase" \
        "$(T show -pqv -t "$P" @fl_phase)" ""
}

# ---------------------------------------------------------------------------
# T25 — THE MIRROR. The floated pane's process exiting inside the float (`:q`
# in a floated nvim) destroys the holder with the nested client still attached;
# the global detach-on-destroy=off then re-homed that client onto the source
# session, turning the popup into a live mirror of the session behind it, full
# key surface included — prefix z dug a deeper float instead of closing, and
# ctrl-d drove the real panes through the glass. The holder-local
# detach-on-destroy=on must detach the client instead. Shipped as a live
# incident (2026-08-14, a floated nvim).
# ---------------------------------------------------------------------------
t25() {
    fresh; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1 &
    sleep 2
    holder=$(T list-sessions -F '#{session_name}' | grep '^_float_' | head -1)
    if [ -z "$holder" ]; then no "T25 holder exists" "none"; return; fi

    # A real nested client on the holder — exactly what the container's
    # blocking attach is.
    O kill-server 2>/dev/null; sleep 0.2
    O -f /dev/null new-session -d -s o -x 200 -y 50
    O send-keys -t o "TMUX= tmux -L $SOCK attach -t '=$holder'" Enter
    sleep 2.5
    check "T25 nested client is on the holder" \
        "$(T list-clients -F '#{client_session}' | head -1)" "$holder"

    # The pane dies in the float — same as quitting the floated program.
    T kill-pane -t "$P"; sleep 1

    check "T25 holder died with its pane" \
        "$(T list-sessions -F '#{session_name}' | grep -c '^_float_' || true)" "0"
    check "T25 client detached, not re-homed into a mirror" \
        "$(T list-clients 2>/dev/null | wc -l | tr -d ' ')" "0"
}

# ---------------------------------------------------------------------------
# T26 — scratch popup: opens AT the pane's cwd, and its whole lifecycle leaves
# nothing behind — no session, no holder, no pane state. SCRATCH_CMD is the
# seam standing in for the interactive shell.
# ---------------------------------------------------------------------------
t26() {
    fresh
    sess_before=$(T list-sessions | wc -l | tr -d ' ')

    # No client to draw on: scratch must fail without creating anything —
    # there is no state machine to roll back, and this proves it.
    P0=$(T display -p -t t '#{pane_id}')
    R "$FLOAT" scratch "$P0" >/dev/null 2>&1
    check "T26 clientless scratch creates nothing" \
        "$(T list-sessions | wc -l | tr -d ' ')" "$sess_before"

    O kill-server 2>/dev/null; sleep 0.2
    O -f /dev/null new-session -d -s o -x 200 -y 50
    O send-keys -t o "TMUX= tmux -L $SOCK -f '$CONF' attach -t t" Enter
    sleep 2.5
    C=$(T list-clients -F '#{client_name}' 2>/dev/null | head -1)
    if [ -z "$C" ]; then no "T26 client attached" "no client"; return; fi

    mkdir -p "$SANDBOX/scr-cwd"
    P=$(T split-window -P -F '#{pane_id}' -c "$SANDBOX/scr-cwd" -t t)
    sleep 0.3
    SCRATCH_CMD="pwd > '$SANDBOX/scratch-out'" R "$FLOAT" scratch "$P" "$C" >/dev/null 2>&1
    sleep 0.5
    check "T26 scratch opened at the pane's cwd" \
        "$(grep -c 'scr-cwd$' "$SANDBOX/scratch-out" 2>/dev/null || true)" "1"
    check "T26 scratch leaves no session behind" \
        "$(T list-sessions | wc -l | tr -d ' ')" "$sess_before"
    check "T26 scratch leaves no holder or float state" \
        "$(T list-panes -a -F '#{@fl_phase}' | grep -c . || true)" "0"
}

# ---------------------------------------------------------------------------
# T27 — THE GHOST CLIENT. A client that was suspended and never resumed shares
# the live client's tty name; `-c <name>` resolves by name, first match, and
# does not skip suspended clients — while list-clients hides them. So the
# popup is drawn onto a stopped client and nothing appears; toggle and scratch
# both went dark for a day (2026-08-16). live_client() must notice the name is
# poisoned and let tmux pick the client that actually pressed the key.
# The ghost here is manufactured for real: suspend the inner client, then
# attach again from the SAME outer pane so both share one pty.
# ---------------------------------------------------------------------------
t27() {
    fresh
    O kill-server 2>/dev/null; sleep 0.2
    O -f /dev/null new-session -d -s o -x 200 -y 50
    O send-keys -t o "TMUX= tmux -L $SOCK -f '$CONF' attach -t t" Enter
    sleep 2.5
    C=$(T list-clients -F '#{client_name}' 2>/dev/null | head -1)
    if [ -z "$C" ]; then no "T27 client attached" "no client"; return; fi
    ghost=$(T display -p -c "$C" '#{client_pid}')
    T suspend-client -t "$C"; sleep 1.5              # outer shell gets its prompt back
    O send-keys -t o "TMUX= tmux -L $SOCK -f '$CONF' attach -t t" Enter
    sleep 2.5
    live=$(T list-clients -F '#{client_pid}' 2>/dev/null | head -1)
    if [ -z "$live" ] || [ "$live" = "$ghost" ]; then
        no "T27 ghost + live client share a name" "live=[$live] ghost=[$ghost]"
        kill -9 "$ghost" 2>/dev/null; return
    fi
    ok "T27 ghost + live client share a name"
    # The premise: name resolution prefers the ghost. If a future tmux fixes
    # that, this reads the live pid and the guard is simply idle — still pass.
    resolved=$(T display -p -c "$C" '#{client_pid}')
    [ "$resolved" = "$ghost" ] && echo "       (name resolves to the ghost — the trap is armed)"

    P=$(T display -p -t t '#{pane_id}')
    SCRATCH_CMD='sleep 4' R "$FLOAT" scratch "$P" "$C" >/dev/null 2>&1 &
    sleep 1.5
    check "T27 scratch is drawn on the live client, not the ghost" \
        "$(O capture-pane -p -t o | grep -c 'scratch ·' || true)" "1"
    T display-popup -C 2>/dev/null; sleep 0.5       # no -c: best client = live
    kill -9 "$ghost" 2>/dev/null                    # stopped process; would outlive the suite
}

WANT="${*:-}"
echo "tmux $(tmux -V) — pane control suite"
for c in t12 t13 t5 t1 t2 t4 t3 t6 t7 t7b t8 t9 t10 t11 t14 \
         t15 t16 t17 t18 t18b t18c t19 t20 t21 t22 t23 t24 t25 t26 t27; do
    n=$(echo "$c" | tr 'a-z' 'A-Z')
    want "$n" && { echo "[$n]"; $c; }
done
echo
printf 'passed %d, failed %d%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED)}"
[ "$FAIL" -eq 0 ]
