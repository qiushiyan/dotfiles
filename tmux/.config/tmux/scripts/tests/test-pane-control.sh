#!/usr/bin/env bash
# test-pane-control.sh — the pinned traps for pane mode + floating zoom.
#
# Each case exists because something specific can silently go wrong; the
# comment on each says what. Runs entirely on throwaway sockets, against the
# WORKING TREE's scripts and tmux.conf — never a live tmux server, never the
# stowed copies. Usage: bash test-pane-control.sh [T1 T5 ...]

set -uo pipefail

SOCK="pctest-$$"
OUTER="pcouter-$$"

# The working tree these tests belong to, not $HOME: the stowed copies are
# whatever `main` installed, so grading them passes a branch whose scripts are
# broken. The scripts and tmux.conf's bindings still reach their siblings
# through ~/.config/tmux/scripts, which SANDBOX_HOME below points here.
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TREE=$(cd "$HERE/../.." && pwd)                  # <repo>/tmux/.config/tmux
CONF="$TREE/tmux.conf"
FLOAT="$TREE/scripts/tmux-float-pane.sh"
RELOC="$TREE/scripts/tmux-pane-relocate.sh"
SAVE="$TREE/scripts/tmux-resurrect-save.sh"
LIB="$TREE/scripts/lib/tmux-common.sh"

PASS=0; FAIL=0; FAILED=""

T() { tmux -L "$SOCK" "$@"; }
O() { tmux -L "$OUTER" "$@"; }

# Everything this suite writes goes under one temp root, removed on exit.
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/pane-control-test.XXXXXX")
SANDBOX_RESURRECT="$SANDBOX/resurrect"
mkdir -p "$SANDBOX_RESURRECT"

# The HOME the test server, its panes, and every script run under. The config,
# scripts and themes are this tree's; plugins are the installed ones (not in
# Git), which T21 needs to reach resurrect's real save.sh. TPM reads its plugin
# list from $HOME/.config/tmux/tmux.conf, not tmux's -f file, so without that
# link the server runs with no plugins and T12 checks an ordering nothing
# contests. The halt file is continuum's own switch for its restore-on-start,
# which would otherwise replay a sandbox snapshot into a later case's server
# whenever no other tmux process happens to be running. The empty .zshrc keeps
# the user's rc out of the test panes: its precmd hooks are production code
# and would be a second writer on the server under test (docs/testing.md).
SANDBOX_HOME="$SANDBOX/home"
mkdir -p "$SANDBOX_HOME/.config/tmux"
ln -s "$TREE/tmux.conf" "$SANDBOX_HOME/.config/tmux/tmux.conf"
ln -s "$TREE/scripts" "$SANDBOX_HOME/.config/tmux/scripts"
ln -s "$TREE/themes" "$SANDBOX_HOME/.config/tmux/themes"
ln -s "$HOME/.config/tmux/plugins" "$SANDBOX_HOME/.config/tmux/plugins"
: > "$SANDBOX_HOME/tmux_no_auto_restore"
: > "$SANDBOX_HOME/.zshrc"

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
    # kill-server leaves the socket file; both names carry this run's pid.
    rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCK" "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$OUTER"
    [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
}
trap cleanup EXIT

# Poll until `cmd...` prints exactly `want`, for up to 5s; the status says
# whether it arrived. A fixed sleep is sized for the slowest machine and still
# loses the race on a cold one; the caller's check() reports what was there.
wait_for() { # <want> <cmd...>
    local want="$1" _; shift
    for _ in $(seq 1 50); do
        [ "$("$@" 2>/dev/null)" = "$want" ] && return 0
        sleep 0.1
    done
    return 1
}

# A fresh test server. new-session RETURNING is not the server being ready —
# the config is still loading behind it, plugins included — and a pane id read
# too early comes back empty, after which every command targets nothing and
# the assertions compare empty strings. Poll for the pane; without one the
# case fails here rather than passing on nothing (callers: `fresh || return`).
fresh() {
    T kill-server 2>/dev/null; sleep 0.2       # let the old server finish exiting
    # No inherited XDG roots: TPM and resurrect prefer them to HOME.
    env -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME="$SANDBOX_HOME" \
        tmux -L "$SOCK" -f "$CONF" new-session -d -s t -x 200 -y 50 2>/dev/null
    SOCKPATH=""
    wait_for 1 eval 'T list-panes -t t -F "#{pane_id}" | grep -c "^%"'
    SOCKPATH=$(T display -p '#{socket_path}' 2>/dev/null)
    if [ -z "$SOCKPATH" ]; then
        no "harness: the test server came up" "no server on $SOCK — the case did not run"
        return 1
    fi
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
R() { HOME="$SANDBOX_HOME" TMUX="$SOCKPATH,0,0" FLOAT_GRACE_SECS=1 bash "$@"; }

# Float WITHOUT presenting it — the state a container that died instantly would
# leave. The recovery cases are about exactly that window, and a real toggle now
# (correctly) rolls back when presentation fails, so it cannot be observed via R.
# With no container to block on, the toggle returns once the float is staged.
RS() { FLOAT_SKIP_CONTAINER=1 R "$@"; }
# One shell snippet against the shared library, on the test server.
lib() { TMUX="$SOCKPATH,0,0" bash -c ". '$LIB'; $1" 2>/dev/null; }
tiled() { T list-panes -t "$1" -f '#{==:#{pane_floating_flag},0}' -F '#{pane_id}' 2>/dev/null | tr '\n' ' '; }
layout() { T display-message -p -t "$1" '#{window_layout}' 2>/dev/null; }
# What the outer pane shows (the inner client's drawing, popups included).
on_screen() { O capture-pane -p -t o | grep -qF -- "$1" && echo 1 || echo 0; }
holders() { T list-sessions -F '#{session_name}' 2>/dev/null | grep -c '^_float_'; }
float_clients() { T list-clients -F '#{session_name}' 2>/dev/null | grep -c '^_float_'; }
key_table() { T display -p -c "$C" '#{client_key_table}' 2>/dev/null; }

ok()   { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); FAILED="$FAILED ${1%% *}"; printf '  \033[31mFAIL\033[0m %s\n       %s\n' "$1" "$2"; }
check(){ [ "$2" = "$3" ] && ok "$1" || no "$1" "expected [$3] got [$2]"; }

want() { case " ${WANT:-} " in *" $1 "*) return 0;; esac; [ -z "${WANT:-}" ]; }

# A real client on the test server: an outer tmux supplies the pty and its
# shell runs the attach (T27 needs that shell, to attach again from the same
# pty). The outer server gets the sandbox HOME too, so its shell starts quiet
# and fast. Sets C once the client is attached and its window has taken the
# client's size — attaching resizes the window, so a baseline taken earlier
# never matches. Fails the case otherwise (callers: `attach_client Tn || return`).
attach_client() { # <case> [width height [session]]
    local w="${2:-200}" h="${3:-50}" s="${4:-t}"
    O kill-server 2>/dev/null; sleep 0.2
    HOME="$SANDBOX_HOME" O -f /dev/null new-session -d -s o -x "$w" -y "$h"
    O send-keys -t o "TMUX= tmux -L $SOCK attach -t '=$s'" Enter
    C=""
    if wait_for "$w $w" eval 'T list-clients -F "#{client_width} #{window_width}" | head -1'; then
        C=$(T list-clients -F '#{client_name}' 2>/dev/null | head -1)
    fi
    [ -n "$C" ] && return 0
    no "$1 client attached" "no client on $SOCK"
    return 1
}

# ---------------------------------------------------------------------------
# T5 — identity round trip. select-layout restores geometry but NOT identity;
# a naive float round trip returns %0 %1 %2 as %0 %2 %1.
# ---------------------------------------------------------------------------
t5() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; T split-window -v -t "$W"; sleep 0.3
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    before=$(tiled "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
    sleep 1.5          # age the holder past the 1s grace: the FIRST pass must take it
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
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
    fresh || return
    W1=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W1"; sleep 0.2
    T new-session -d -s t2 -x 200 -y 50; sleep 0.2
    W2=$(T display -p -t t2 '#{window_id}')
    T split-window -v -t "$W2"; sleep 0.3
    b1=$(tiled "$W1"); b2=$(tiled "$W2")
    P1=$(T display -p -t "$W1" '#{pane_id}'); P2=$(T display -p -t "$W2" '#{pane_id}')
    RS "$FLOAT" toggle "$P1" >/dev/null 2>&1 & j1=$!
    RS "$FLOAT" toggle "$P2" >/dev/null 2>&1 & j2=$!
    wait "$j1" "$j2"
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
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

# (T8, the marked-pane inversion on the retired `marked` verb, lives on as T31:
# the same trap on the put path.)

# T9 — inside a float the holder's restricted key table must be in force, so
# this config's destructive prefix verbs are simply not reachable.
t9() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
    holder=$(T list-sessions -F '#{session_name}' | grep '^_float_' | head -1)
    if [ -z "$holder" ]; then no "T9 holder exists" "none"; R "$FLOAT" restore "$P" >/dev/null 2>&1; return; fi
    # NB: bare name, not "=$holder" — show-option's target is a target-pane and
    # the `=` exact-session form reads back empty with rc=0 there.
    check "T9 holder uses the restricted root table" \
        "$(T show -qv -t "$holder" key-table)" "float-root"
    check "T9 holder is marked as ours" \
        "$([ -n "$(T show -qv -t "$holder" @fl_holder_nonce)" ] && echo yes)" "yes"
    # The contract is what is NOT there; harmless keys may come and go.
    check "T9 no kill or new-window verb is reachable inside the float" \
        "$({ T list-keys -T float-root; T list-keys -T float-prefix; } 2>/dev/null \
            | grep -cE 'kill-(pane|window|session|server)|new-window' || true)" "0"
    R "$FLOAT" restore "$P" >/dev/null 2>&1; sleep 0.4
}

# ---------------------------------------------------------------------------
# T12 — continuum's timer saves through the float-normalising wrapper. Nothing
# else drives that path (T34 covers prefix p and the status row on a client).
# resurrect sets its own save path on every load, so the config's override
# holds only if it runs after TPM; the premise proves the plugin loaded and
# contested it (its restore path is set by the same function).
# ---------------------------------------------------------------------------
t12() {
    fresh || return
    check "T12 (premise) TPM loaded resurrect on the test server" \
        "$(T show -gqv @resurrect-restore-script-path | grep -c '/tmux-resurrect/scripts/restore.sh$')" "1"
    check "T12 resurrect save routed through the wrapper" \
        "$(T show -gv @resurrect-save-script-path | grep -c 'tmux-resurrect-save.sh')" "1"
}

# T13 — a native floating pane must not corrupt counts or snapshots.
t13() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; sleep 0.2       # side by side: a left-of exists
    T new-pane -t "$W" 2>/dev/null; sleep 0.5
    check "T13 window_panes counts the native float (why we filter)" \
        "$(T display -p -t "$W" '#{window_panes}')" "3"
    check "T13 the lib's tiled_panes ignores it" "$(lib "tiled_panes $W" | wc -l | tr -d ' ')" "2"
    fl=$(T list-panes -t "$W" -f '#{==:#{pane_floating_flag},1}' -F '#{pane_id}')
    # push takes its pane as an argument, but resolves {left-of} from the
    # CURRENT pane. With the float current that is nothing and push no-ops
    # guard or not; with a tiled pane current it is a real neighbour. tmux
    # then refuses the swap on its own ("cannot swap floating panes"), so the
    # flag alone would pass without the guard; the damage the guard prevents
    # is an undo record for a move that never happened.
    T select-pane -t "$(T list-panes -t "$W" -f '#{==:#{pane_floating_flag},0}' -F '#{pane_id}' | tail -1)"
    R "$RELOC" push left "$fl" >/dev/null 2>&1; sleep 0.3
    check "T13 push refuses a floating pane, journalling nothing" \
        "$(T display -p -t "$fl" '#{pane_floating_flag}') [$(T show -wqv -t "$W" @pane_journal)]" "1 []"
}

# ---------------------------------------------------------------------------
# T11 — mode bracketing. Verbs that change where you are must NOT re-enter the
# sticky table: break moves you to another window, and float opens a blocking
# container whose nested client must not inherit a pending table. (The verbs
# that do stay — h/j/k/l, p, G, and the picker — are pressed on a real client
# in T18b, T34 and T35.)
# ---------------------------------------------------------------------------
t11() {
    fresh || return
    check "T11 float does not re-enter the mode" \
        "$(T list-keys -T panes | awk '$4=="z"' | grep -c 'switch-client -T panes' || true)" "0"
    check "T11 break does not re-enter the mode" \
        "$(T list-keys -T panes | awk '$4=="b"' | grep -c 'switch-client -T panes' || true)" "0"
    # Dropping -b leaves T35 green (the popup still works), so only this row
    # sees it.
    check "T11 pick is backgrounded (display-popup blocks its issuer)" \
        "$(T list-keys -T panes | awk '$4=="w"' | grep -c 'run-shell -b' || true)" "1"
}

# ---------------------------------------------------------------------------
# T14 — THE END-TO-END PATH. Everything above drives toggle/restore directly,
# which never exercises the container: display-popup needs a client, and with
# none attached it fails after the break has already happened. This drives the
# real key, through a real pty, and closes it with the real in-float key.
# ---------------------------------------------------------------------------
t14() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')

    attach_client T14 || return
    T select-pane -t "$P"
    # capture AFTER the client attaches: attaching resizes the window, so a
    # baseline taken before it would never match the restored layout
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    before_w=$(T display-message -p -t "$P" '#{pane_width}')

    O send-keys -t o C-b; sleep 0.3; O send-keys -t o z
    wait_for 1 float_clients

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
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o z
    wait_for "$before_l" layout "$W"     # the restore's last step

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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; T split-window -v -t "$W"; sleep 0.3
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')

    # The fake save must actually be reachable, or "aborted" below proves
    # nothing — without the RESURRECT_SAVE seam the wrapper would exec the real
    # save and the marker would be absent either way. So first the control:
    # with nothing floated, the wrapper hands off and the fake save runs.
    marker="$SANDBOX/real-save-ran"; rm -f "$marker"
    printf '#!/bin/sh\ntouch %s\n' "$marker" > "$SANDBOX/fake-save.sh"
    chmod +x "$SANDBOX/fake-save.sh"
    RESURRECT_SAVE="$SANDBOX/fake-save.sh" R "$SAVE" quiet >/dev/null 2>&1
    check "T17 (control) with nothing floated the wrapper runs the save" \
        "$([ -e "$marker" ] && echo ran || echo aborted)" "ran"
    rm -f "$marker"

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

    # and the wrapper must abort rather than exec the save.
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
    RESURRECT_SAVE="$SANDBOX/fake-save.sh" R "$SAVE" quiet >/dev/null 2>&1
    check "T17 wrapper does not run the real save when a float is stuck" \
        "$([ -e "$marker" ] && echo ran || echo aborted)" "aborted"
    rm -f "$SANDBOX/fake-save.sh" "$marker"
}

# ---------------------------------------------------------------------------
# T18 — undo. Completely uncovered before this review.
# ---------------------------------------------------------------------------
t18() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; sleep 0.3
    before_o=$(tiled "$W")
    right=$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)
    R "$RELOC" push left "$right" >/dev/null 2>&1; sleep 0.4
    swapped=$(tiled "$W")
    check "T18 push swapped"                "$([ "$swapped" != "$before_o" ] && echo yes)" "yes"
    R "$RELOC" undo "$W" >/dev/null 2>&1; sleep 0.4
    check "T18 undo restores the pane order" "$(tiled "$W")" "$before_o"

    # edge relocation undo
    fresh || return; W=$(T display -p -t t '#{window_id}')
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; sleep 0.3
    attach_client T18b || return
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    T select-pane -t "$P" -T "notes"          # a named pane, to check the title
    attach_client T20 120 36 || return
    T select-pane -t "$P"
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o z
    wait_for 1 on_screen 'notes'

    cap=$(O capture-pane -p -t o)
    check "T20 float draws a heavy border" \
        "$(printf '%s' "$cap" | grep -cm1 '[┏┓┗┛━┃]' || true)" "1"
    check "T20 float does not draw the global rounded border" \
        "$(printf '%s' "$cap" | grep -cm1 '[╭╮╰╯]' || true)" "0"
    check "T20 title names the pane, not the holder nonce" \
        "$(printf '%s' "$cap" | grep -cm1 'notes' || true)" "1"

    # and the other popups in this config keep the global rounded frame
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o z
    wait_for 0 holders
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3

    check "T21 test server points at the sandbox" \
        "$(T show -gv @resurrect-dir)" "$SANDBOX_RESURRECT"
    # The bindings name ~/.config/tmux/scripts; on the user's HOME that is the
    # installed copy, and every key-driven case would grade it instead.
    check "T21 the server's bindings reach this tree's scripts" \
        "$(T run-shell 'cd ~/.config/tmux/scripts && pwd -P')" "$(cd "$TREE/scripts" && pwd -P)"

    local before_last before_count after_last after_count sandbox_before sandbox_after
    before_last=$(readlink "$REAL_RESURRECT/last" 2>/dev/null || echo none)
    before_count=$(ls -1 "$REAL_RESURRECT" 2>/dev/null | wc -l | tr -d ' ')
    sandbox_before=$(ls -1 "$SANDBOX_RESURRECT" 2>/dev/null | wc -l | tr -d ' ')

    R "$SAVE" quiet >/dev/null 2>&1
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; T split-window -v -t "$W"; sleep 0.3
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
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
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
    check "T23 float works again after rollback" \
        "$(tiled "$W" | grep -c "$P" || true)" "0"
    R "$FLOAT" restore "$P" >/dev/null 2>&1; sleep 0.5
}

# T24 — a container that fails to open must not strand the pane outside its
# window. An invalid @float_border makes display-popup fail.
t24() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
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
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
    holder=$(T list-sessions -F '#{session_name}' | grep '^_float_' | head -1)
    if [ -z "$holder" ]; then no "T25 holder exists" "none"; return; fi

    # A real nested client on the holder — exactly what the container's
    # blocking attach is.
    attach_client T25 200 50 "$holder" || return
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
# nothing behind — no session, no holder, no pane state; that row pins the
# design (scratch never touches the float's state machine). SCRATCH_CMD is the
# seam standing in for the interactive shell.
# ---------------------------------------------------------------------------
t26() {
    fresh || return
    sess_before=$(T list-sessions | wc -l | tr -d ' ')

    attach_client T26 || return

    mkdir -p "$SANDBOX/scr-cwd"
    P=$(T split-window -P -F '#{pane_id}' -c "$SANDBOX/scr-cwd" -t t)
    sleep 0.3
    SCRATCH_CMD="pwd > '$SANDBOX/scratch-out'" R "$FLOAT" scratch "$P" "$C" >/dev/null 2>&1
    sleep 0.5
    check "T26 scratch opened at the pane's cwd" \
        "$(grep -c 'scr-cwd$' "$SANDBOX/scratch-out" 2>/dev/null || true)" "1"
    check "T26 scratch leaves no session and no float state behind" \
        "$(T list-sessions | wc -l | tr -d ' ') $(T list-panes -a -F '#{@fl_phase}' | grep -c . || true)" \
        "$sess_before 0"
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
    fresh || return
    attach_client T27 || return
    ghost=$(T display -p -c "$C" '#{client_pid}')
    T suspend-client -t "$C"; sleep 1.5              # outer shell gets its prompt back
    O send-keys -t o "TMUX= tmux -L $SOCK attach -t '=t'" Enter
    wait_for 1 eval 'T list-clients | wc -l | tr -d " "'   # the ghost is not listed
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
    wait_for 1 on_screen 'scratch ·'
    check "T27 scratch is drawn on the live client, not the ghost" \
        "$(O capture-pane -p -t o | grep -c 'scratch ·' || true)" "1"
    T display-popup -C 2>/dev/null; sleep 0.5       # no -c: best client = live

    # The pane-mode picker takes the same client name from its binding. It
    # used to accept any name `display -c` answered for — the ghost answers.
    T new-window -d -t t 2>/dev/null; sleep 0.3
    R "$RELOC" pick "$P" "$C" >/dev/null 2>&1 &
    wait_for 1 on_screen 'move pane to'
    check "T27 the pick popup is drawn on the live client, not the ghost" \
        "$(O capture-pane -p -t o | grep -c 'move pane to' || true)" "1"
    T display-popup -C 2>/dev/null; sleep 0.5
    kill -9 "$ghost" 2>/dev/null                    # stopped process; would outlive the suite
}

# ---------------------------------------------------------------------------
# T28 — hold lifecycle. The hold is ONE pane id in a private global option; a
# second hold replaces it; a refused hold (a native float) leaves the existing
# hold alone; release is idempotent.
# ---------------------------------------------------------------------------
t28() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    a=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    b=$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)
    R "$RELOC" hold "$a" >/dev/null 2>&1
    check "T28 hold stores the pane id only" "$(T show -gqv @pane_hold)" "$a"
    check "T28 hold writes a display label" \
        "$([ -n "$(T show -gqv @pane_hold_label)" ] && echo yes)" "yes"
    R "$RELOC" hold "$b" >/dev/null 2>&1
    check "T28 a second hold replaces the first" "$(T show -gqv @pane_hold)" "$b"
    T new-pane -t "$W" 2>/dev/null; sleep 0.4
    fl=$(T list-panes -t "$W" -f '#{==:#{pane_floating_flag},1}' -F '#{pane_id}')
    R "$RELOC" hold "$fl" >/dev/null 2>&1
    check "T28 holding a native float is refused and keeps the previous hold" \
        "$(T show -gqv @pane_hold)" "$b"
    R "$RELOC" release >/dev/null 2>&1
    check "T28 release clears the hold" "[$(T show -gqv @pane_hold)][$(T show -gqv @pane_hold_label)]" "[][]"
    R "$RELOC" release >/dev/null 2>&1
    check "T28 release is idempotent" "[$(T show -gqv @pane_hold)]" "[]"
}

# ---------------------------------------------------------------------------
# T29 — the puts that must NOT move anything, and which of them clear the
# hold: empty (no-op, nothing to clear), the held pane gone (clears), same
# window (clears), and a split made after the hold (still valid — the hold is
# the pane, not its window's shape).
# ---------------------------------------------------------------------------
t29() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.2
    T new-window -t t; sleep 0.3; W2=$(T display -p -t t '#{window_id}')
    t2=$(T display -p -t "$W2" '#{pane_id}')
    l2=$(layout "$W2")
    R "$RELOC" put "$t2" >/dev/null 2>&1; sleep 0.3
    check "T29 empty put moves nothing" "$(layout "$W2")" "$l2"

    a=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    R "$RELOC" hold "$a" >/dev/null 2>&1
    T kill-pane -t "$a"; sleep 0.3
    R "$RELOC" put "$t2" >/dev/null 2>&1; sleep 0.3
    check "T29 a dead held pane clears the hold on put" "[$(T show -gqv @pane_hold)]" "[]"
    check "T29 ...and moves nothing" "$(layout "$W2")" "$l2"

    T split-window -h -t "$W2"; sleep 0.3
    x=$(T list-panes -t "$W2" -F '#{pane_id}' | head -1)
    y=$(T list-panes -t "$W2" -F '#{pane_id}' | tail -1)
    lb=$(layout "$W2"); ob=$(tiled "$W2")
    R "$RELOC" hold "$x" >/dev/null 2>&1
    R "$RELOC" put "$y" >/dev/null 2>&1; sleep 0.3
    check "T29 same-window put changes nothing" "$(tiled "$W2")$(layout "$W2")" "$ob$lb"
    check "T29 same-window put releases the hold" "[$(T show -gqv @pane_hold)]" "[]"

    # hold, then split the held pane's window: the hold survives and puts
    b=$(T display -p -t "$W" '#{pane_id}')
    R "$RELOC" hold "$b" >/dev/null 2>&1
    T split-window -v -t "$W"; sleep 0.3
    R "$RELOC" put "$y" >/dev/null 2>&1; sleep 0.4
    check "T29 a hold survives a split in its window" \
        "$(tiled "$W2" | grep -c "$b" || true)" "1"
}

# ---------------------------------------------------------------------------
# T30 — placement. The held pane lands as the full-height RIGHT column and is
# active, whether the target has one pane or several; the source window's only
# pane leaving closes that window.
# ---------------------------------------------------------------------------
t30() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.2
    T new-window -t t; sleep 0.3; W2=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W2"; sleep 0.2
    p=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    t2=$(T display -p -t "$W2" '#{pane_id}')
    R "$RELOC" hold "$p" >/dev/null 2>&1
    R "$RELOC" put "$t2" >/dev/null 2>&1; sleep 0.4
    geo=$(T display -p -t "$p" '#{pane_at_right}#{pane_at_top}#{pane_at_bottom}')
    check "T30 multi-pane target: full-height right column" "$geo" "111"
    check "T30 the moved pane is the active one" "$(T display -p -t "$W2" '#{pane_id}')" "$p"
    check "T30 the session's current window is the target" "$(T display -p -t t '#{window_id}')" "$W2"
    check "T30 hold cleared after a successful put" "[$(T show -gqv @pane_hold)]" "[]"

    # one-pane target, and the source's only pane: the source window closes
    T new-window -t t; sleep 0.3; W3=$(T display -p -t t '#{window_id}')
    t3=$(T display -p -t "$W3" '#{pane_id}')
    only=$(T display -p -t "$W" '#{pane_id}')
    check "T30 (premise) source window has one pane" "$(tiled "$W" | wc -w | tr -d ' ')" "1"
    R "$RELOC" hold "$only" >/dev/null 2>&1
    R "$RELOC" put "$t3" >/dev/null 2>&1; sleep 0.4
    check "T30 one-pane target: ordinary two-column split" \
        "$(T display -p -t "$only" '#{pane_at_right}#{pane_at_left}') $(T display -p -t "$t3" '#{pane_at_left}#{pane_at_right}')" "10 10"
    check "T30 the emptied source window closed" \
        "$(T list-windows -t t -F '#{window_id}' | grep -c "^$W\$" || true)" "0"
}

# ---------------------------------------------------------------------------
# T31 — the mark trap, on the new path. With an unrelated pane MARKED, put must
# still move the HELD pane (move-pane without -s would move the marked one).
# ---------------------------------------------------------------------------
t31() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.2
    T new-window -t t; sleep 0.3; W2=$(T display -p -t t '#{window_id}')
    held=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    marked=$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)
    t2=$(T display -p -t "$W2" '#{pane_id}')
    T select-pane -t "$marked" -m
    R "$RELOC" hold "$held" >/dev/null 2>&1
    R "$RELOC" put "$t2" >/dev/null 2>&1; sleep 0.4
    check "T31 the held pane moved, the marked one stayed" \
        "$(tiled "$W2" | grep -c "$held" || true)$(tiled "$W" | grep -c "$marked" || true)" "11"
}

# ---------------------------------------------------------------------------
# T32 — float collision. A held pane floated by prefix z is inside a holder
# session with restore metadata; put must refuse AND keep the hold, so closing
# the float makes it usable again. A native float as the held pane clears; a
# native float as the destination is refused.
# ---------------------------------------------------------------------------
t32() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.2
    T new-window -t t; sleep 0.3; W2=$(T display -p -t t '#{window_id}')
    t2=$(T display -p -t "$W2" '#{pane_id}')
    p=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    R "$RELOC" hold "$p" >/dev/null 2>&1
    RS "$FLOAT" toggle "$p" >/dev/null 2>&1
    check "T32 (premise) held pane is floated" "$(tiled "$W" | grep -c "$p" || true)" "0"
    R "$RELOC" put "$t2" >/dev/null 2>&1; sleep 0.4
    check "T32 put refuses a floated held pane" "$(tiled "$W2" | grep -c "$p" || true)" "0"
    check "T32 ...and keeps the hold" "$(T show -gqv @pane_hold)" "$p"
    R "$FLOAT" restore "$p" >/dev/null 2>&1; sleep 0.5
    R "$RELOC" put "$t2" >/dev/null 2>&1; sleep 0.4
    check "T32 put succeeds once the float is closed" "$(tiled "$W2" | grep -c "$p" || true)" "1"

    # a native float in the hold slot: can never be put — cleared
    T new-pane -t "$W2" 2>/dev/null; sleep 0.4
    fl=$(T list-panes -t "$W2" -f '#{==:#{pane_floating_flag},1}' -F '#{pane_id}')
    T set -g @pane_hold "$fl"
    R "$RELOC" put "$(T display -p -t "$W" '#{pane_id}')" >/dev/null 2>&1; sleep 0.3
    check "T32 a native-float hold is cleared on put" "[$(T show -gqv @pane_hold)]" "[]"

    # a native float as the DESTINATION pane: refused, hold kept
    q=$(T display -p -t "$W" '#{pane_id}')
    R "$RELOC" hold "$q" >/dev/null 2>&1
    R "$RELOC" put "$fl" >/dev/null 2>&1; sleep 0.3
    check "T32 a native-float destination is refused" "$(tiled "$W2" | grep -c "$q" || true)" "0"
    check "T32 ...and the hold is kept" "$(T show -gqv @pane_hold)" "$q"
}

# ---------------------------------------------------------------------------
# T33 — a put and a break invalidate the push journal on both ends. Without
# this, journal_pop reaches a record whose pane set no longer matches, refuses
# it, keeps it, and `u` is stuck there forever.
# ---------------------------------------------------------------------------
t33() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; T split-window -v -t "$W"; sleep 0.3
    T new-window -t t; sleep 0.3; W2=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W2"; sleep 0.3
    # push resolves {left-of} against the CURRENT pane (a binding always runs
    # there), so each push is made in its own window as the current one
    T select-window -t "$W2"; T select-pane -t "$(T list-panes -t "$W2" -F '#{pane_id}' | tail -1)"
    R "$RELOC" push left "$(T list-panes -t "$W2" -F '#{pane_id}' | tail -1)" >/dev/null 2>&1; sleep 0.3
    T select-window -t "$W"; T select-pane -t "$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)"
    R "$RELOC" push left "$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)" >/dev/null 2>&1; sleep 0.3
    check "T33 (premise) both windows have journal records" \
        "$(T show -wqv -t "$W" @pane_journal | grep -c . || true)$(T show -wqv -t "$W2" @pane_journal | grep -c . || true)" "11"
    p=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    R "$RELOC" hold "$p" >/dev/null 2>&1
    R "$RELOC" put "$(T display -p -t "$W2" '#{pane_id}')" >/dev/null 2>&1; sleep 0.4
    check "T33 put clears the source window's journal" "[$(T show -wqv -t "$W" @pane_journal)]" "[]"
    check "T33 put clears the target window's journal" "[$(T show -wqv -t "$W2" @pane_journal)]" "[]"

    T select-window -t "$W"; T select-pane -t "$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)"
    R "$RELOC" push left "$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)" >/dev/null 2>&1; sleep 0.3
    check "T33 (premise) a fresh record before break" "$(T show -wqv -t "$W" @pane_journal | grep -c . || true)" "1"
    R "$RELOC" break "$(T list-panes -t "$W" -F '#{pane_id}' | head -1)" >/dev/null 2>&1; sleep 0.4
    check "T33 break clears the source window's journal" "[$(T show -wqv -t "$W" @pane_journal)]" "[]"
    check "T33 break made a new window" "$(T list-windows -t t | wc -l | tr -d ' ')" "3"
}

# ---------------------------------------------------------------------------
# T34 — the key surface and the status row, on a real client. g leaves the
# mode and the spare row says what is held through ordinary window navigation;
# p puts and stays in the mode; G stays; any unbound key and Esc leave it (a
# custom table cannot trap the client); m/M are gone; at 80 columns the
# compact cheat sheet still names the hold verbs.
# ---------------------------------------------------------------------------
t34() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.2
    T new-window -t t; sleep 0.2; W2=$(T display -p -t t '#{window_id}')
    T select-window -t "$W"; sleep 0.2
    attach_client T34 || return
    check "T34 m and M are retired" "$(T list-keys -T panes | awk '$4=="m"||$4=="M"' | wc -l | tr -d ' ')" "0"

    p=$(T display -p -t "$W" '#{pane_id}')
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o p; sleep 0.5; O send-keys -t o g; sleep 1
    check "T34 g leaves the mode" "$(T display -p -c "$C" '#{client_key_table}')" "root"
    check "T34 g held the pane" "$(T show -gqv @pane_hold)" "$p"
    row() { O capture-pane -p -t o | sed -n 2p; }
    check "T34 the row shows the hold outside the mode" "$(row | grep -c 'HOLDING' || true)" "1"
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o C-l; sleep 1     # ordinary window nav
    check "T34 navigated to the other window" "$(T display -p -c "$C" '#{window_id}')" "$W2"
    check "T34 the hold survives window navigation" "$(row | grep -c 'HOLDING' || true)" "1"
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o p; sleep 0.5; O send-keys -t o p; sleep 1.2
    check "T34 p put the pane here" "$(tiled "$W2" | grep -c "$p" || true)" "1"
    check "T34 p stays in the mode" "$(T display -p -c "$C" '#{client_key_table}')" "panes"
    check "T34 the row is the cheat sheet again (redrawn after re-entry)" "$(row | grep -c 'p put' || true)" "1"
    O send-keys -t o G; sleep 0.8
    check "T34 G stays in the mode" "$(T display -p -c "$C" '#{client_key_table}')" "panes"
    O send-keys -t o .; sleep 0.8          # '.' is unbound in the panes table
    check "T34 an unbound key leaves the mode" "$(T display -p -c "$C" '#{client_key_table}')" "root"
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o p; sleep 0.5; O send-keys -t o Escape; sleep 0.8
    check "T34 Esc leaves the mode" "$(T display -p -c "$C" '#{client_key_table}')" "root"

    # 80 columns: the compact row
    attach_client T34 80 24 || return
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o p; sleep 1
    r=$(row)
    check "T34 80-col row names hold and put" "$(printf '%s' "$r" | grep -c 'g hold.*p put.*w pick' || true)" "1"
    check "T34 80-col row is not truncated" "$(printf '%s' "$r" | grep -c 'Esc done' || true)" "1"
    O send-keys -t o Escape; sleep 0.3
}

# ---------------------------------------------------------------------------
# T35 — the picker, end to end on a real client: w opens the popup with the
# other window of this session and a preview of it — never the source window,
# never another session's; Enter moves this pane there, lands beside it, and
# returns to pane mode.
# ---------------------------------------------------------------------------
t35() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.2
    T new-window -t t -n zebra; sleep 0.2; W2=$(T display -p -t t '#{window_id}')
    T send-keys -t "$W2" 'echo PREVIEW-SENTINEL' Enter; sleep 0.3
    T rename-window -t "$W" source
    T new-session -d -s t2 -n elsewhere; sleep 0.2
    T select-window -t "$W"; sleep 0.2
    attach_client T35 || return
    p=$(T display -p -t "$W" '#{pane_id}')
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o p; sleep 0.5; O send-keys -t o w
    wait_for 1 on_screen 'PREVIEW-SENTINEL'      # the list, then its preview
    cap=$(O capture-pane -p -t o)
    # the fzf row is "<index>: zebra  · 1 pane"; the bare name also sits in the
    # status bar's window list, so match the row's own shape
    check "T35 popup lists the other window" "$(printf '%s' "$cap" | grep -c 'zebra  · 1 pane' || true)" "1"
    check "T35 ...and neither the source window nor another session's" \
        "$(printf '%s' "$cap" | grep -cE '(source|elsewhere)  · ' || true)" "0"
    check "T35 preview shows the target's content" \
        "$([ "$(printf '%s' "$cap" | grep -c 'PREVIEW-SENTINEL' || true)" -ge 1 ] && echo yes)" "yes"
    O send-keys -t o Enter
    wait_for 0 on_screen 'move pane to'; wait_for panes key_table
    check "T35 Enter moved the pane there" "$(tiled "$W2" | grep -c "$p" || true)" "1"
    check "T35 landed in the target window" "$(T display -p -c "$C" '#{window_id}')" "$W2"
    check "T35 the moved pane is active" "$(T display -p -c "$C" '#{pane_id}')" "$p"
    check "T35 back in pane mode" "$(T display -p -c "$C" '#{client_key_table}')" "panes"
    O send-keys -t o Escape; sleep 0.3
}

# ---------------------------------------------------------------------------
# T36 — picker cancellation and the hold race. Esc moves nothing and leaves an
# earlier hold alone. The picker carries its source as an argument: a hold
# replaced while the popup is open must not change what Enter moves.
# ---------------------------------------------------------------------------
t36() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.2
    T new-window -t t; sleep 0.2; W2=$(T display -p -t t '#{window_id}')
    T select-window -t "$W"; sleep 0.2
    attach_client T36 || return
    src=$(T display -p -t "$W" '#{pane_id}')
    other=$(T list-panes -t "$W" -F '#{pane_id}' | grep -v "^$src\$" | head -1)
    T set -g @pane_hold "$other"                       # an earlier hold, unrelated
    l1=$(layout "$W"); l2=$(layout "$W2")
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o p; sleep 0.5; O send-keys -t o w
    wait_for 1 on_screen '  · 1 pane'           # fzf's row, not just the popup frame
    O send-keys -t o Escape
    wait_for 0 on_screen 'move pane to'; wait_for panes key_table
    check "T36 Esc moves nothing" "$(layout "$W")$(layout "$W2")" "$l1$l2"
    check "T36 Esc leaves the earlier hold alone" "$(T show -gqv @pane_hold)" "$other"
    check "T36 Esc returns to pane mode" "$(T display -p -c "$C" '#{client_key_table}')" "panes"
    # Leave the mode without a key: right after a popup closes, a lone Escape
    # is held and merges with the next key (C-b becomes M-C-b), so `prefix p w`
    # below would type "pw" into the shell instead.
    T switch-client -c "$C" -T root

    O send-keys -t o C-b; sleep 0.3; O send-keys -t o p; sleep 0.5; O send-keys -t o w
    wait_for 1 on_screen '  · 1 pane'
    T set -g @pane_hold "$other"                       # replaced while the popup is up
    O send-keys -t o Enter
    wait_for 0 on_screen 'move pane to'; wait_for panes key_table
    check "T36 Enter moved the captured source, not the hold" \
        "$(tiled "$W2" | grep -c "$src" || true)$(tiled "$W" | grep -c "$other" || true)" "11"
    check "T36 the replacement hold is untouched" "$(T show -gqv @pane_hold)" "$other"
    O send-keys -t o Escape; sleep 0.3
}

# ---------------------------------------------------------------------------
# T37 — with no other window in the session there is no popup; the mode is
# simply re-entered. (What the popup lists is T35's.)
# ---------------------------------------------------------------------------
t37() {
    fresh || return
    attach_client T37 || return
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o p; sleep 0.5; O send-keys -t o w; sleep 1.5
    check "T37 no other window: no popup" "$(O capture-pane -p -t o | grep -c 'move pane to' || true)" "0"
    check "T37 no other window: back in pane mode" "$(T display -p -c "$C" '#{client_key_table}')" "panes"
    O send-keys -t o Escape; sleep 0.3
}

# ---------------------------------------------------------------------------
# T38 — the shared library's contract, starting with the trap it exists for:
# tmux 3.7c answers `display-message -t <gone pane>` with status 0 and empty
# output, so an existence check on the status calls every dead pane alive.
# The float's private copies did; a toggle on a dead pane then got as far as
# creating a holder session before break-pane failed. The session-created
# hook makes that transient holder observable. Also pinned: the palette
# helper's output, which every fzf popup passes straight to `fzf --color`.
# ---------------------------------------------------------------------------
t38() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    P=$(T display -p -t "$W" '#{pane_id}')
    check "T38 a live pane exists"   "$(lib "pane_exists $P && echo y || echo n")" "y"
    check "T38 a dead pane does not" "$(lib 'pane_exists %9999 && echo y || echo n')" "n"
    check "T38 a live window exists" "$(lib "win_exists $W && echo y || echo n")" "y"
    check "T38 a dead window does not" "$(lib 'win_exists @9999 && echo y || echo n')" "n"

    T set-hook -g session-created 'set -ga @t38_created x'
    RS "$FLOAT" toggle %9999 >/dev/null 2>&1
    check "T38 floating a dead pane touches nothing (no holder, even briefly)" \
        "[$(T show -gqv @t38_created)]" "[]"

    cols=$(lib fzf_colors_from_palette)
    # fzf rejects a malformed --color with status 2; 1 is only "no match".
    check "T38 fzf accepts the palette as its --color value" \
        "$(fzf --color "$cols" --filter x </dev/null >/dev/null 2>&1; [ $? -le 1 ] && echo yes)" "yes"
    check "T38 ...taken from the live palette" \
        "$(printf '%s' "$cols" | cut -d, -f1,4,7)" \
        "hl:$(T show -gv @thm_red),bg+:$(T show -gv @thm_surface_0),pointer:$(T show -gv @thm_mauve)"
    check "T38 ...the footer muted as the header is" \
        "$(printf '%s' "$cols" | tr ',' '\n' | grep -E '^(header|footer):' | tr '\n' ' ')" \
        "header:$(T show -gv @thm_overlay_2) footer:$(T show -gv @thm_overlay_2) "
    T set -gu @thm_mauve
    check "T38 with no palette fzf keeps its defaults" "$(lib fzf_colors_from_palette)" "fg+:-1"
}

# ---------------------------------------------------------------------------
# T39 — the rename popup, end to end on a real client. The label must land on
# the pane M was pressed on, even though focus moves while the popup is open:
# the binding passes the pane as a run-shell ARGUMENT (the float's shape).
# ---------------------------------------------------------------------------
t39() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; sleep 0.3
    A=$(T list-panes -t "$W" -F '#{pane_id}' | head -1)
    B=$(T list-panes -t "$W" -F '#{pane_id}' | tail -1)

    attach_client T39 || return
    T select-pane -t "$A"
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o M
    wait_for 1 on_screen 'pane title >'
    check "T39 the rename popup opened" "$(O capture-pane -p -t o | grep -c 'pane title >' || true)" "1"
    T select-pane -t "$B"                       # focus moves while it is open
    O send-keys -t o -l 'notes'; sleep 0.3; O send-keys -t o Enter
    wait_for notes eval 'T display -p -t "$A" "#{pane_title}"'
    check "T39 the label landed on the pane M was pressed on" \
        "$(T display -p -t "$A" '#{pane_title}')" "notes"
    check "T39 the other pane kept its title" \
        "$(T display -p -t "$B" '#{pane_title}' | grep -c '^notes$' || true)" "0"
    check "T39 naming froze the title and raised the border" \
        "$(T show -pv -t "$A" allow-set-title) $(T show -wv -t "$W" pane-border-status)" "off top"
}

# ---------------------------------------------------------------------------
# T40 — a refusal shows its reason. run-shell answers a non-zero exit by
# replacing the status message with "'<command>' returned 1", so prefix z in a
# one-pane window used to show that instead of the script's own explanation.
# Pressed on a real client, since only run-shell produces the clobbering.
# ---------------------------------------------------------------------------
t40() {
    fresh || return
    attach_client T40 || return
    check "T40 (premise) the window has one pane" "$(tiled t | wc -w | tr -d ' ')" "1"
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o z; sleep 1.5
    screen=$(O capture-pane -p -t o)
    check "T40 prefix z in a one-pane window says why" \
        "$(printf '%s' "$screen" | grep -c 'only one pane in this window' || true)" "1"
    check "T40 ...and run-shell does not replace it" \
        "$(printf '%s' "$screen" | grep -c 'returned 1' || true)" "0"
}

# ---------------------------------------------------------------------------
# T41 — restore's second branch: the same panes, resized while floated. The
# resize is the user's newer work, so the pane order comes back but the
# recorded layout must NOT be replayed over it.
# ---------------------------------------------------------------------------
t41() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; T split-window -v -t "$W"; sleep 0.3
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
    T resize-pane -t "$(tiled "$W" | cut -d' ' -f1)" -x 50; sleep 0.2
    check "T41 (premise) the source window was resized while floated" \
        "$(tiled "$W" | grep -c "$P" || true) $(T display -p -t "$(tiled "$W" | cut -d' ' -f1)" '#{pane_width}')" "0 50"
    R "$FLOAT" restore "$P" >/dev/null 2>&1
    check "T41 the pane order is restored" "$(tiled "$W")" "$before_o"
    check "T41 the recorded layout is not replayed over the resize" \
        "$([ "$(layout "$W")" != "$before_l" ] && echo kept)" "kept"
}

# ---------------------------------------------------------------------------
# T42 — restore's rebuild branch: the source window is gone but its session
# lives. The pane comes home in a new window under the old name, with no
# recovery session and no placeholder left beside it. (The old index is only
# tried: renumber-windows has already moved a neighbour into it. T19 kills the
# session too; T17 fakes a gone session.)
# ---------------------------------------------------------------------------
t42() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T rename-window -t "$W" home
    T split-window -v -t "$W"; sleep 0.2
    T new-window -d -t t; sleep 0.2                # keeps the session alive
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
    T kill-window -t "$W"
    R "$FLOAT" restore "$P" >/dev/null 2>&1
    check "T42 the pane is back in its own session" "$(T display -p -t "$P" '#{session_name}')" "t"
    check "T42 ...in a rebuilt window under the old name" \
        "$(T display -p -t "$P" '#{window_name}')" "home"
    check "T42 ...alone (the placeholder shell is gone)" \
        "$(T display -p -t "$P" '#{window_panes}')" "1"
    check "T42 no recovery session and no holder" \
        "$(T list-sessions -F '#{session_name}' | grep -c '^recovered-\|^_float_' || true)" "0"
}

# ---------------------------------------------------------------------------
# T43 — the sweep's young-holder re-check. A holder inside the grace window is
# skipped (its container may still be attaching); the sweep runs only on
# client-attached, so without the re-check nothing would look at it again
# until the next attach. Sweep the instant the float is staged: only the
# re-check, after the grace, can bring the pane home. Ages are whole seconds
# (session_created against date +%s), so a 1s grace can already read as
# expired on the first pass; this case runs a 3s grace and checks both halves —
# the first pass leaves the holder alone, and the re-check then restores it.
# ---------------------------------------------------------------------------
t43() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -v -t "$W"; sleep 0.3
    before=$(tiled "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    RS "$FLOAT" toggle "$P" >/dev/null 2>&1
    local created age
    created=$(T list-sessions -F '#{session_created} #{session_name}' | awk '$2 ~ /^_float_/ {print $1; exit}')
    age=$(( $(date +%s) - ${created:-0} ))
    check "T43 (premise) the holder is younger than the grace" \
        "$( [ -n "$created" ] && [ "$age" -lt 2 ] && echo young || echo "age=$age")" "young"
    HOME="$SANDBOX_HOME" TMUX="$SOCKPATH,0,0" FLOAT_GRACE_SECS=3 \
        bash "$FLOAT" sweep >/dev/null 2>&1 &
    local sweeper=$!
    sleep 1                                       # well inside the 3s re-check sleep
    check "T43 the first pass leaves a young holder alone" \
        "$(tiled "$W" | grep -c "$P" || true) $(holders)" "0 1"
    wait "$sweeper"
    check "T43 the sweep's re-check restored a holder that was too young at first" \
        "$(tiled "$W")" "$before"
    check "T43 holder cleaned up" "$(holders)" "0"
}

# ---------------------------------------------------------------------------
# T44 — a save while a float is LIVE: a real container on a real client, then
# the resurrect wrapper. prepare-save must dismiss the container and restore
# the pane exactly, and the save must then go ahead with nothing floated. T3,
# T15 and T17 all float without a container. (This is the path that once ran
# two restorers at once; T15 pins the claim that serializes them, since the
# race is too narrow to reproduce here on demand.)
# ---------------------------------------------------------------------------
t44() {
    fresh || return; W=$(T display -p -t t '#{window_id}')
    T split-window -h -t "$W"; T split-window -v -t "$W"; sleep 0.3
    attach_client T44 || return
    before_o=$(tiled "$W"); before_l=$(layout "$W")
    P=$(T display -p -t "$W" '#{pane_id}')
    O send-keys -t o C-b; sleep 0.3; O send-keys -t o z
    wait_for 1 float_clients
    check "T44 (premise) the float is live in a container" \
        "$(float_clients) $(tiled "$W" | grep -c "$P" || true)" "1 0"

    # The fake save records what a real one would snapshot: how many holders
    # exist at that moment. (It inherits R's TMUX, so it asks the test server.)
    # The dismissed container restores the pane by itself too, but only
    # afterwards — a save that did not wait for it would record the float.
    marker="$SANDBOX/t44-holders-at-save"; rm -f "$marker"
    printf '#!/bin/sh\ntmux list-sessions -F "#{session_name}" | grep -c "^_float_" > %s\n' \
        "$marker" > "$SANDBOX/fake-save.sh"
    chmod +x "$SANDBOX/fake-save.sh"
    RESURRECT_SAVE="$SANDBOX/fake-save.sh" R "$SAVE" quiet >/dev/null 2>&1
    sleep 0.5                                     # let the container's own restore no-op
    check "T44 the save went ahead, with no float left to record" \
        "$(cat "$marker" 2>/dev/null || echo 'no save')" "0"
    check "T44 the pane is back in its exact slot" "$(tiled "$W")|$(layout "$W")" "$before_o|$before_l"
    check "T44 the container is gone and the holder with it" "$(float_clients) $(holders)" "0 0"
    check "T44 the outer client stayed on its session" "$(T display -p -c "$C" '#{session_name}')" "t"
    rm -f "$SANDBOX/fake-save.sh" "$marker"
}

WANT="${*:-}"
echo "tmux $(tmux -V) — pane control suite"
for c in t12 t13 t5 t1 t2 t4 t3 t6 t7 t7b t9 t11 t14 \
         t15 t16 t17 t18 t18b t18c t19 t20 t21 t22 t23 t24 t25 t26 t27 \
         t28 t29 t30 t31 t32 t33 t34 t35 t36 t37 t38 t39 t40 \
         t41 t42 t43 t44; do
    n=$(echo "$c" | tr 'a-z' 'A-Z')
    want "$n" && { echo "[$n]"; $c; }
done
echo
printf 'passed %d, failed %d%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED)}"
[ "$FAIL" -eq 0 ]
