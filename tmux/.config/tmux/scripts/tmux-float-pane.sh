#!/usr/bin/env bash
# tmux-float-pane.sh — `prefix z`: maximize the current pane into a floating
# overlay instead of tmux's all-or-nothing zoom, so the rest of the window
# stays visible and LIVE behind it. A second `prefix z` puts it back exactly.
#
# WHY A HOLDER SESSION. tmux cannot display an existing pane inside a popup,
# and tmux 3.7's native floating panes explicitly cannot yet convert between
# floating and tiled ("Many obvious features are not yet available ... the
# ability to ... change them between floating and tiles" — CHANGES 3.6b→3.7).
# So the pane is genuinely relocated: broken out into a detached *holder*
# session, and a container (a popup running a nested `attach`) displays that
# session. The pane keeps running throughout — only its geometry changes.
#
# Panes behind the container keep redrawing: the man page's "Panes are not
# updated while a popup is present" is stale (CHANGES: "Do not freeze output in
# panes when a popup is open, let them continue to redraw"). Only the region
# the container physically covers is clipped. That is the whole point of this
# feature over `resize-pane -Z`.
#
#   toggle <pane> [client]  float the pane (no-op if already floating)
#   restore <pane>          put it back; IDEMPOTENT — safe to call twice, and
#                           safe to call on a pane that was never floated
#   sweep                   restore every stranded holder (crash recovery)
#   prepare-save            sweep, then block until settled — for the resurrect
#                           save wrapper, so a snapshot never records a float
#   container <pane>        INTERNAL: runs inside the container; attaches, then
#                           restores when the attach returns
#
# STATE lives in pane-local user options on the floated pane, never in globals.
# The pane is the identity that moves, so the metadata moves with it — and two
# panes can be floated at once without colliding. (The older `prefix P` /
# rename-pane popups stash context in GLOBAL env vars; that idiom races when
# two clients act at once, which is why nothing here uses it.)
#
#   @fl_phase   floating | restoring   — presence means "this pane is floated"
#   @fl_nonce   unique id; also marks the holder session (@fl_holder_nonce)
#   @fl_holder  holder session name
#   @fl_src_*   where it came from: session, window id, window index+name
#   @fl_order   ordered TILED pane ids of the source window, before the break
#   @fl_layout  window_layout of the source window, before the break
#   @fl_active  which pane was active before the float
#   @fl_exp_*   the expected post-break order/layout — the optimistic-
#               concurrency check on restore (see restore_pane)
#
# RESTORE IS OPTIMISTIC, NOT A BLIND REPLAY. `select-layout <string>` restores
# geometry but NOT pane identity — the layout string addresses panes by index
# order, so a naive break/join round trip on %0 %1 %2 comes back as %0 %2 %1
# with the geometry "right" and the wrong panes in the slots. So we permute the
# panes back to the recorded order with swap-pane FIRST, then apply the layout.
# And we only do that when the source window still looks like what we left; if
# another client rearranged it meanwhile, its work wins (see the cases below).
#
# FLOATING PANES CONTAMINATE BOTH SIGNALS. tmux 3.7's native floats are counted
# by #{window_panes} and embedded in #{window_layout} (as a trailing <...>
# segment), so every pane list, count, and comparison here filters on
# #{pane_floating_flag} — otherwise a stray `prefix *` float would corrupt a
# snapshot or let us break out the last real pane.

set -uo pipefail

SELF="$HOME/.config/tmux/scripts/tmux-float-pane.sh"
CLAUDE_CTX="$HOME/.config/tmux/scripts/tmux-claude-ctx.sh"

# Container geometry. Percentages of the client, leaving a frame of live
# window visible around the edge — the reason to float rather than zoom.
FLOAT_W="${FLOAT_W:-90%}"
FLOAT_H="${FLOAT_H:-90%}"

# How long a restore claim is honoured before another restorer may steal it.
# Only reached when a restorer died mid-flight.
FLOAT_CLAIM_TTL="${FLOAT_CLAIM_TTL:-30}"

msg() { tmux display-message "$*" 2>/dev/null || true; }

# --- small helpers over tmux state -------------------------------------------

# Tiled (non-floating) pane ids of a window, in index order. The `-f` filter is
# server-side, so this never sees a native floating pane.
tiled_panes() {
    tmux list-panes -t "$1" -f '#{==:#{pane_floating_flag},0}' -F '#{pane_id}' 2>/dev/null
}

pane_opt()     { tmux show -pqv -t "$1" "$2" 2>/dev/null; }
set_pane_opt() { tmux set -p -t "$1" "$2" "$3" 2>/dev/null; }
unset_pane_opt() { tmux set -p -u -t "$1" "$2" 2>/dev/null; }

pane_exists()  { tmux display-message -p -t "$1" '#{pane_id}' >/dev/null 2>&1; }
win_exists()   { tmux display-message -p -t "$1" '#{window_id}' >/dev/null 2>&1; }
sess_exists()  { tmux has-session -t "=$1" 2>/dev/null; }

# Border state is WINDOW-scoped and shared between producers, so relocation is
# reconciled by the single owner, with no target (= all-window sweep). A moved
# pane strands markers on BOTH ends, and a targeted call can only fix one.
reconcile() { TMUX_PANE= bash "$CLAUDE_CTX" reconcile >/dev/null 2>&1 || true; }

# Restore `want_order` (space-separated pane ids) as the window's tiled pane
# ORDER, then apply `layout`. Order first: the layout string is positional.
apply_order_and_layout() {
    local win="$1" want_order="$2" layout="$3" i=0 want have
    for want in $want_order; do
        pane_exists "$want" || { i=$((i + 1)); continue; }
        have=$(tiled_panes "$win" | sed -n "$((i + 1))p")
        [ -n "$have" ] && [ "$have" != "$want" ] && \
            tmux swap-pane -d -s "$want" -t "$have" 2>/dev/null
        i=$((i + 1))
    done
    [ -n "$layout" ] && tmux select-layout -t "$win" "$layout" 2>/dev/null
    return 0
}

# --- float --------------------------------------------------------------------

# --- the container adapter ----------------------------------------------------
# Together these are the only code that knows the holder is shown by a popup
# running a nested attach; everything else here is container-agnostic. Migrating
# to a native floating pane (tmux/tmux#5135, slated 3.8) means rewriting THESE,
# not one line — an earlier comment claimed the swap was a single function,
# which was untrue: staging the key surface, the in-container lifecycle, and
# dismissal are container-specific too.
#
#   container_restrict_keys / container_release_keys  stage & unstage the holder
#   open_container                                    put it on screen
#   container_dismiss                                 take it off screen
#   the `container` verb (bottom)                     attach, then restore

# The nested client would otherwise inherit this config's whole prefix surface
# and drive it against the holder. BOTH halves are required:
#   key-table float-root  — the client's root table inside the float
#   prefix/prefix2 None   — without this tmux intercepts the prefix key ITSELF
#                           and jumps straight to the built-in `prefix` table,
#                           bypassing a custom root table entirely (verified:
#                           #{client_key_table} read `prefix`, not
#                           `float-prefix`). With no prefix to intercept the
#                           C-b/C-a bindings in float-root fire, so `prefix z`
#                           still means "close the float".
container_restrict_keys() {
    local holder="$1"
    tmux set -t "$holder" key-table float-root 2>/dev/null
    tmux set -t "$holder" prefix  None 2>/dev/null
    tmux set -t "$holder" prefix2 None 2>/dev/null
}

# Undo the above. Needed whenever a holder is surfaced to the user as a recovery
# session: it has to behave like a normal session, or the configured prefixes
# are dead in it.
container_release_keys() {
    local holder="$1" o
    for o in key-table prefix prefix2 status; do
        tmux set -t "$holder" -u "$o" 2>/dev/null
    done
}

# Detaching the nested client ends the blocking attach inside the container,
# which is what triggers that container's own restore.
container_dismiss() {
    tmux detach-client -s "=$1" 2>/dev/null || true
}

open_container() {
    local holder="$1" pane="$2" client="$3" sock
    sock=$(tmux display-message -p '#{socket_path}' 2>/dev/null)

    local args=(-E -w "$FLOAT_W" -h "$FLOAT_H" -T " ${holder#_float_} ")
    [ -n "$client" ] && args+=(-c "$client")

    # display-popup BLOCKS its issuing command until dismissed, which is why
    # the key binding calls this script with `run-shell -b`.
    tmux display-popup "${args[@]}" \
        "exec bash '$SELF' container '$pane' '$holder' '$sock'"
}

float_pane() {
    local pane="$1" client="${2:-}"

    pane_exists "$pane" || { msg "float: no such pane"; return 1; }

    # A native floating pane has nothing to float INTO and cannot be swapped.
    if [ "$(tmux display-message -p -t "$pane" '#{pane_floating_flag}')" = 1 ]; then
        msg "float: this is already a floating pane"; return 1
    fi

    # Already floated (e.g. a second client raced us). Idempotent no-op.
    [ -n "$(pane_opt "$pane" @fl_phase)" ] && return 0

    local win sess
    win=$(tmux display-message -p -t "$pane" '#{window_id}')
    sess=$(tmux display-message -p -t "$pane" '#{session_name}')

    # Floating the only tiled pane would destroy the window and leave nothing
    # behind the container — which is the entire value of this over zoom.
    local order
    order=$(tiled_panes "$win" | tr '\n' ' ')
    if [ "$(printf '%s' "$order" | wc -w | tr -d ' ')" -lt 2 ]; then
        msg "float: only one pane in this window — use prefix Z to zoom"
        return 1
    fi

    local nonce holder
    nonce="$$-$(date +%s)"
    holder="_float_$nonce"

    # Snapshot BEFORE the break.
    local layout active win_idx win_name
    layout=$(tmux display-message -p -t "$win" '#{window_layout}')
    active=$(tmux display-message -p -t "$win" '#{pane_id}')
    win_idx=$(tmux display-message -p -t "$win" '#{window_index}')
    win_name=$(tmux display-message -p -t "$win" '#{window_name}')

    # The holder: detached, no status bar (the container should be all pane),
    # and a restricted root key table so the nested client cannot drive this
    # config's destructive verbs against the holder (see float-root in
    # tmux.conf). Marked with the nonce so `sweep` can recognise it as ours and
    # never adopt an unrelated session that happens to match the name.
    tmux new-session -d -s "$holder" 2>/dev/null || {
        msg "float: could not create holder session"; return 1; }
    tmux set -t "$holder" @fl_holder_nonce "$nonce" 2>/dev/null
    tmux set -t "$holder" status off 2>/dev/null
    container_restrict_keys "$holder"
    local placeholder
    placeholder=$(tmux display-message -p -t "$holder" '#{window_id}')

    # PUBLISH RECOVERY STATE BEFORE THE DESTRUCTIVE MOVE. The pane leaving its
    # window and the metadata describing where it came from must not be
    # separated by a window in which the process can die: a marked holder
    # containing a live pane with no @fl_* is unrecoverable — the sweep finds
    # the pane but restore has nothing to act on, so it sits invisible in an
    # internal session. Writing first means the worst intermediate state is a
    # pane that still has its metadata, which recovery can always resolve —
    # either forward (it moved) or backward (it did not).
    set_pane_opt "$pane" @fl_phase   preparing
    set_pane_opt "$pane" @fl_nonce   "$nonce"
    set_pane_opt "$pane" @fl_holder  "$holder"
    set_pane_opt "$pane" @fl_src_sess "$sess"
    set_pane_opt "$pane" @fl_src_win  "$win"
    set_pane_opt "$pane" @fl_src_idx  "$win_idx"
    set_pane_opt "$pane" @fl_src_name "$win_name"
    set_pane_opt "$pane" @fl_order   "$order"
    set_pane_opt "$pane" @fl_layout  "$layout"
    set_pane_opt "$pane" @fl_active  "$active"

    if ! tmux break-pane -d -s "$pane" -t "$holder:" 2>/dev/null; then
        clear_state "$pane"
        tmux kill-session -t "=$holder" 2>/dev/null
        msg "float: break-pane failed"; return 1
    fi
    tmux kill-window -t "$placeholder" 2>/dev/null

    # Point the holder at the floated pane's window so the nested attach lands
    # on it rather than on some other window.
    local fwin
    fwin=$(tmux display-message -p -t "$pane" '#{window_id}')
    tmux select-window -t "$fwin" 2>/dev/null

    # What we expect the source window to look like while floated — the
    # optimistic-concurrency check on restore. Only meaningful now that the
    # move has actually happened, hence after the break.
    if win_exists "$win"; then
        set_pane_opt "$pane" @fl_exp_order  "$(tiled_panes "$win" | tr '\n' ' ')"
        set_pane_opt "$pane" @fl_exp_layout "$(tmux display-message -p -t "$win" '#{window_layout}')"
    fi
    set_pane_opt "$pane" @fl_phase floating

    reconcile
    open_container "$holder" "$pane" "$client"
}

# --- restore ------------------------------------------------------------------

# Idempotent. Every exit path from the container calls this, and so does the
# sweep; whichever gets there first wins and the rest become no-ops.
restore_pane() {
    local pane="$1"

    pane_exists "$pane" || return 0
    local phase; phase=$(pane_opt "$pane" @fl_phase)
    [ -n "$phase" ] || return 0          # not floated (or already restored)

    # CLAIM IT ATOMICALLY. `set-option -o` is set-if-absent: it fails (rc≠0,
    # "already set: …") and leaves the existing value alone, which is exactly
    # the compare-and-set this needs. Overwriting @fl_phase instead was NOT a
    # lock — every caller that saw any phase proceeded, so two restorers ran
    # the same join-pane + permutation + layout replay and reliably corrupted
    # the result (a 3-pane window came back as %0 %2 %1). That path is directly
    # reachable: prepare_save detaches the container, waking its restore, and
    # then calls restore itself.
    #
    # A claim outlives a restorer killed mid-flight, so it carries a timestamp
    # and is stealable after FLOAT_CLAIM_TTL — otherwise one crash would wedge
    # the pane in its holder permanently.
    local now claim claim_at
    now=$(date +%s)
    if ! tmux set -p -t "$pane" -o @fl_claim "$$:$now" 2>/dev/null; then
        claim=$(pane_opt "$pane" @fl_claim)
        claim_at=${claim##*:}
        if [ -n "$claim_at" ] && [ $((now - claim_at)) -lt "$FLOAT_CLAIM_TTL" ]; then
            return 0                     # a live restorer owns this pane
        fi
        set_pane_opt "$pane" @fl_claim "$$:$now"   # stale — take it over
    fi

    # Re-read after winning: the state may have been rewritten between our
    # first look and the claim.
    phase=$(pane_opt "$pane" @fl_phase)
    [ -n "$phase" ] || { unset_pane_opt "$pane" @fl_claim; return 0; }
    set_pane_opt "$pane" @fl_phase restoring

    # `preparing` means we died between publishing state and completing the
    # move, so the pane may never have left. If it is still in its source
    # window there is nothing to restore — just drop the unused holder.
    if [ "$phase" = preparing ]; then
        local cur_win; cur_win=$(tmux display-message -p -t "$pane" '#{window_id}' 2>/dev/null)
        if [ -n "$cur_win" ] && [ "$cur_win" = "$(pane_opt "$pane" @fl_src_win)" ]; then
            local h; h=$(pane_opt "$pane" @fl_holder)
            [ -n "$h" ] && sess_exists "$h" && \
                [ -z "$(tmux list-panes -s -t "=$h" -F '#{pane_id}' 2>/dev/null)" ] && \
                tmux kill-session -t "=$h" 2>/dev/null
            clear_state "$pane"
            reconcile
            return 0
        fi
    fi

    local holder src_sess src_win order layout active exp_order exp_layout
    holder=$(pane_opt "$pane" @fl_holder)
    src_sess=$(pane_opt "$pane" @fl_src_sess)
    src_win=$(pane_opt "$pane" @fl_src_win)
    order=$(pane_opt "$pane" @fl_order)
    layout=$(pane_opt "$pane" @fl_layout)
    active=$(pane_opt "$pane" @fl_active)
    exp_order=$(pane_opt "$pane" @fl_exp_order)
    exp_layout=$(pane_opt "$pane" @fl_exp_layout)

    local landed=""

    if win_exists "$src_win"; then
        local now_order now_layout sibling
        now_order=$(tiled_panes "$src_win" | tr '\n' ' ')
        now_layout=$(tmux display-message -p -t "$src_win" '#{window_layout}')
        sibling=$(tiled_panes "$src_win" | head -1)

        if [ -n "$sibling" ]; then
            tmux join-pane -s "$pane" -t "$sibling" 2>/dev/null && landed=1
        fi

        if [ -n "$landed" ]; then
            if [ "$now_order" = "$exp_order" ] && [ "$now_layout" = "$exp_layout" ]; then
                # Untouched since we left: exact restore.
                apply_order_and_layout "$src_win" "$order" "$layout"
            elif [ "$now_order" = "$exp_order" ]; then
                # Same panes, someone resized/rearranged. Their geometry is
                # newer than our snapshot — restore identity order only, and
                # let the live layout stand rather than clobbering their work.
                apply_order_and_layout "$src_win" "$order" ""
            else
                # Panes were added or removed. The recorded slot no longer
                # exists; the pane is back in its window and that is the
                # contract we can still honour. Leave the live layout alone.
                :
            fi
        fi
    fi

    # Degraded paths: the source window (or its whole session) went away.
    if [ -z "$landed" ]; then
        local src_idx src_name
        src_idx=$(pane_opt "$pane" @fl_src_idx)
        src_name=$(pane_opt "$pane" @fl_src_name)
        if sess_exists "$src_sess"; then
            # Rebuild a window near where it came from and move the pane in.
            local newwin
            newwin=$(tmux new-window -d -P -F '#{window_id}' \
                        -t "$src_sess:${src_idx:-}" -n "${src_name:-recovered}" 2>/dev/null) \
                || newwin=$(tmux new-window -d -P -F '#{window_id}' \
                        -t "$src_sess:" -n "${src_name:-recovered}" 2>/dev/null)
            if [ -n "$newwin" ]; then
                local ph; ph=$(tmux list-panes -t "$newwin" -F '#{pane_id}' | head -1)
                if tmux join-pane -s "$pane" -t "$ph" 2>/dev/null; then
                    tmux kill-pane -t "$ph" 2>/dev/null
                    landed=1
                fi
            fi
        fi
    fi

    if [ -z "$landed" ]; then
        # Nowhere to go home to. NEVER kill the pane to satisfy cleanup — it is
        # a live process the user cares about. Surface the holder instead, so
        # the pane is reachable rather than hidden in an internal session.
        if [ -n "$holder" ] && sess_exists "$holder"; then
            container_release_keys "$holder"
            tmux set -t "$holder" -u @fl_holder_nonce 2>/dev/null
            tmux rename-session -t "=$holder" "recovered-${holder#_float_}" 2>/dev/null
        fi
        clear_state "$pane"
        reconcile
        msg "float: source window is gone — pane left in a recovered session"
        return 0
    fi

    clear_state "$pane"

    # Follow the pane back and restore focus as it was.
    if [ -n "$active" ] && pane_exists "$active"; then
        tmux select-pane -t "$active" 2>/dev/null
    else
        tmux select-pane -t "$pane" 2>/dev/null
    fi

    # The holder dies on its own once its last pane leaves; only clean up a
    # holder that somehow survived, and only if it is really ours.
    if [ -n "$holder" ] && sess_exists "$holder"; then
        if [ -z "$(tmux list-panes -s -t "=$holder" -F '#{pane_id}' 2>/dev/null)" ]; then
            tmux kill-session -t "=$holder" 2>/dev/null
        fi
    fi

    reconcile
    return 0
}

clear_state() {
    local pane="$1" o
    for o in @fl_phase @fl_nonce @fl_holder @fl_src_sess @fl_src_win \
             @fl_src_idx @fl_src_name @fl_order @fl_layout @fl_active \
             @fl_exp_order @fl_exp_layout @fl_claim; do
        unset_pane_opt "$pane" "$o"
    done
}

# --- sweep / save -------------------------------------------------------------

# Every pane sitting in a session we marked as a holder. Crash recovery: the
# container's shell is what normally calls restore, and a SIGKILL skips it.
# GOTCHA: no `=` prefix on the show-option target. `=name` is the exact-match
# form for a target-SESSION (has-session, kill-session, attach-session all take
# it), but show-option's target is a target-PANE, where `=name` resolves to
# nothing and the option reads back EMPTY with rc=0 — a silent miss, not an
# error. Using it here made every holder look unmarked, so the sweep found
# nothing and a killed container stranded its pane. Holder names carry a pid
# and an epoch, so plain-name matching is unambiguous.
#
# STRANDED means "no container is showing it", not merely "in a holder". The
# sweep runs from the client-attached hook, and a float's own container IS a
# client attaching to a holder — so a sweep that ignored this would fire on
# every float and restore the pane the instant the container opened, undoing
# the feature. (Observed exactly that: the float appeared to do nothing, and
# `detach-on-destroy off` then re-homed the orphaned container client to the
# source session.) An attached holder is a live float; leave it alone.
#
# The grace window covers the gap between break-pane and the container's
# attach, where a holder legitimately has no clients yet and an unrelated
# client attaching could otherwise undo an in-flight float.
FLOAT_GRACE_SECS="${FLOAT_GRACE_SECS:-5}"

holder_sessions() { # every session we marked as a holder
    local s
    while IFS= read -r s; do
        [ -n "$(tmux show -qv -t "$s" @fl_holder_nonce 2>/dev/null)" ] && printf '%s\n' "$s"
    done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
}

# Crash recovery: holders with nothing showing them.
stranded_panes() {
    local s attached created now
    now=$(date +%s)
    while IFS=' ' read -r s attached created; do
        [ -n "$(tmux show -qv -t "$s" @fl_holder_nonce 2>/dev/null)" ] || continue
        [ "${attached:-0}" -gt 0 ] && continue                       # live float
        [ $((now - ${created:-0})) -lt "$FLOAT_GRACE_SECS" ] && continue  # in flight
        tmux list-panes -s -t "=$s" -F '#{pane_id}' 2>/dev/null
    done < <(tmux list-sessions -F '#{session_name} #{session_attached} #{session_created}' 2>/dev/null)
}

# Every floated pane, live containers included — the save path must normalise
# an ACTIVE float, which is precisely what the stranded predicate skips.
all_float_panes() {
    local s
    while IFS= read -r s; do
        tmux list-panes -s -t "=$s" -F '#{pane_id}' 2>/dev/null
    done < <(holder_sessions)
}

# Holders skipped only because they are still inside the grace window.
young_holders() {
    local s attached created now
    now=$(date +%s)
    while IFS=' ' read -r s attached created; do
        [ -n "$(tmux show -qv -t "$s" @fl_holder_nonce 2>/dev/null)" ] || continue
        [ "${attached:-0}" -gt 0 ] && continue
        [ $((now - ${created:-0})) -lt "$FLOAT_GRACE_SECS" ] && printf '%s\n' "$s"
    done < <(tmux list-sessions -F '#{session_name} #{session_attached} #{session_created}' 2>/dev/null)
}

sweep() {
    local p
    while IFS= read -r p; do
        [ -n "$p" ] && restore_pane "$p"
    done < <(stranded_panes)

    # A holder that was too young to judge would otherwise never be recovered:
    # the sweep only runs on client-attached, so nothing would look at it again
    # until the NEXT attach. Wait out the grace and re-check once. The hook runs
    # this backgrounded, so the sleep costs nothing interactive.
    if [ -n "$(young_holders)" ]; then
        sleep "$FLOAT_GRACE_SECS"
        while IFS= read -r p; do
            [ -n "$p" ] && restore_pane "$p"
        done < <(stranded_panes)
    fi
    surface_orphan_holders
    return 0
}

# Last-resort safety net: a marked holder whose panes carry no @fl_* state.
# The ordering fix in float_pane means this can no longer be produced here, but
# it can still arrive from an older build, a partially-restored server, or a
# hand-edited session — and the failure mode is the worst one available: a live
# pane the user cares about, alive and invisible in an internal session. Make it
# a normal, reachable session rather than leaving it hidden.
surface_orphan_holders() {
    local s p has_state
    while IFS= read -r s; do
        [ -n "$s" ] || continue
        [ "$(tmux display-message -p -t "$s" '#{session_attached}' 2>/dev/null)" != 0 ] && continue
        has_state=""
        while IFS= read -r p; do
            [ -n "$(pane_opt "$p" @fl_phase)" ] && { has_state=1; break; }
        done < <(tmux list-panes -s -t "=$s" -F '#{pane_id}' 2>/dev/null)
        [ -n "$has_state" ] && continue
        [ -z "$(tmux list-panes -s -t "=$s" -F '#{pane_id}' 2>/dev/null)" ] && {
            tmux kill-session -t "=$s" 2>/dev/null; continue; }
        container_release_keys "$s"
        tmux set -t "$s" -u @fl_holder_nonce 2>/dev/null
        tmux rename-session -t "=$s" "recovered-${s#_float_}" 2>/dev/null
    done < <(holder_sessions)
    reconcile
    return 0
}

# Used by the resurrect save wrapper. A snapshot taken mid-float records the
# source window WITHOUT the pane plus a `_float_*` session holding it, and
# resurrect does not persist pane user options — so the two halves could never
# be reconnected after a restart. Normalise first, then let the save proceed.
# FAILS CLOSED. Returning success with a float still outstanding is the one
# outcome that must not happen: resurrect overwrites the previous snapshot, so
# saving here would replace a good save with one whose pane and window are
# recorded as unrelated things. Aborting keeps the last good save instead.
prepare_save() {
    local i=0 s p
    # Close any live container first, so its client goes away with the popup
    # instead of being re-homed onto another session when the holder dies
    # (detach-on-destroy is off here).
    while IFS= read -r s; do
        [ -n "$s" ] && container_dismiss "$s"
    done < <(holder_sessions)
    while IFS= read -r p; do
        [ -n "$p" ] && restore_pane "$p"
    done < <(all_float_panes)
    while [ $i -lt 40 ]; do
        [ -z "$(all_float_panes)" ] && return 0
        sleep 0.1
        i=$((i + 1))
    done
    [ -z "$(all_float_panes)" ] && return 0
    msg "resurrect save skipped — a floated pane could not be restored"
    return 1
}

# --- entry --------------------------------------------------------------------

case "${1:-}" in
    toggle)  float_pane "${2:?pane required}" "${3:-}" ;;
    restore) restore_pane "${2:?pane required}" ;;
    sweep)   sweep ;;
    prepare-save) prepare_save ;;
    container)
        # Runs INSIDE the container. The nested attach blocks for as long as the
        # float is up; when it returns (prefix z, prefix d, or the client being
        # killed) we restore. `TMUX=` is mandatory: tmux refuses to nest an
        # attach while $TMUX is set, and $TMUX is always set inside a popup.
        pane="${2:?}" holder="${3:?}" sock="${4:?}"
        TMUX= tmux -S "$sock" attach-session -t "=$holder" 2>/dev/null
        bash "$SELF" restore "$pane"
        ;;
    *)
        printf 'usage: %s {toggle|restore|sweep|prepare-save} ...\n' "${0##*/}" >&2
        exit 64
        ;;
esac
