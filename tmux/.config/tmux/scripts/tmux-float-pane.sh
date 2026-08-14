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
#   scratch <pane> [client] EPHEMERAL popup shell at the pane's current
#                           directory; no holder, no state — see scratch_popup
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
#   @fl_phase   preparing | floating | restoring — presence means the pane is
#               mid-float. `preparing` is written LAST during setup, so an
#               interrupted publication leaves no phase at all.
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

# Border weight for the float specifically. The global popup-border-lines is
# `rounded` and stays that way for the worktree/rename popups — those are
# transient dialogs, while the float is a pane you sit and work in, so it earns
# a heavier edge to separate it from the live window showing through behind it.
# Values: single / rounded / double / heavy / simple / padded / none. `padded`
# is a solid space-drawn band rather than a line — thicker still, if you want
# the float to read as a slab; it takes its colour from popup-border-style's bg.
#   tmux set -g @float_border double
FLOAT_BORDER_DEFAULT=heavy

# The scratch popup must NOT look like the float: ctrl-d in a float kills a
# real process the user cares about, ctrl-d in a scratch is the way out. So the
# scratch is smaller and keeps the transient-dialog rounded border while the
# float wears heavy. Override: tmux set -g @scratch_border <same values>.
SCRATCH_W="${SCRATCH_W:-75%}"
SCRATCH_H="${SCRATCH_H:-75%}"
SCRATCH_BORDER_DEFAULT=rounded

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

# Is this pane currently sitting inside a session we marked as a holder? That,
# not the recorded metadata, is what says whether a float's move happened.
pane_in_holder() {
    local s
    s=$(tmux display-message -p -t "$1" '#{session_name}' 2>/dev/null) || return 1
    [ -n "$s" ] && [ -n "$(tmux show -qv -t "$s" @fl_holder_nonce 2>/dev/null)" ]
}
win_exists()   { tmux display-message -p -t "$1" '#{window_id}' >/dev/null 2>&1; }
sess_exists()  { tmux has-session -t "=$1" 2>/dev/null; }

# Border state is WINDOW-scoped and shared between producers, so relocation is
# reconciled by the single owner, with no target (= all-window sweep). A moved
# pane strands markers on BOTH ends, and a targeted call can only fix one.
reconcile() { TMUX_PANE= bash "$CLAUDE_CTX" reconcile >/dev/null 2>&1 || true; }

# Validate a @*_border override — display-popup rejects an unknown value
# outright, which would fail the whole presentation over a typo.
resolve_border() { # <@option> <default>
    local b
    b=$(tmux show -gqv "$1" 2>/dev/null)
    case "$b" in
        single|rounded|double|heavy|simple|padded|none) printf '%s' "$b" ;;
        "") printf '%s' "$2" ;;
        *)  msg "float: ignoring invalid $1 '$b'"; printf '%s' "$2" ;;
    esac
}

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
    # THE MIRROR TRAP. When the floated pane's process exits IN the float
    # (`:q` in a floated nvim, ctrl-d in a floated shell), the holder — whose
    # only content it is — is destroyed with the nested client still attached.
    # tmux then consults detach-on-destroy, and this config's global `off`
    # re-homes that client to the most recently active session: the popup
    # becomes a live MIRROR of the session it floats over, with the full key
    # surface (float-root died with the holder), where `prefix z` opens a
    # deeper float instead of closing this one and ctrl-d drives the REAL
    # panes through the glass. tmux reads the option from the DYING session,
    # so a holder-local `on` detaches the nested client instead — the blocking
    # attach returns, the container restores (a no-op, the pane is gone), and
    # the popup closes. The user's global preference is untouched.
    tmux set -t "$holder" detach-on-destroy on 2>/dev/null
}

# Undo the above. Needed whenever a holder is surfaced to the user as a recovery
# session: it has to behave like a normal session, or the configured prefixes
# are dead in it.
container_release_keys() {
    local holder="$1" o
    for o in key-table prefix prefix2 status detach-on-destroy; do
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

    local border
    border=$(resolve_border @float_border "$FLOAT_BORDER_DEFAULT")

    # Title the float after what is IN it — the pane's label if it has one, else
    # the running command. (It used to show the holder's nonce, a pid-epoch pair
    # that told the user nothing.) Same rule as pane-border-format: a title
    # equal to the hostname is tmux's unset default, not a real label.
    local title
    title=$(tmux display-message -p -t "$pane" \
        '#{?#{==:#{pane_title},#{host}},#{pane_current_command},#{pane_title}}' 2>/dev/null)
    [ -n "$title" ] || title="zoom"

    local args=(-E -w "$FLOAT_W" -h "$FLOAT_H" -b "$border" -T " $title ")
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

    # A pane already sitting in a holder is the floated pane itself, seen
    # through its container. The phase check above catches it in practice;
    # this holds the invariant even for a holder pane whose state is missing
    # (mid-clear, or joined in by hand) — toggling THAT would break the pane
    # out into a second holder and strand the first float's restore metadata.
    if [ -n "$(tmux show -qv -t "$sess" @fl_holder_nonce 2>/dev/null)" ]; then
        msg "float: already inside a float"; return 1
    fi

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

    # PUBLISH RECOVERY STATE BEFORE THE DESTRUCTIVE MOVE, AND THE PHASE LAST.
    # The pane leaving its window and the metadata describing where it came from
    # must not be separated by a window in which the process can die: a marked
    # holder containing a live pane with no @fl_* is unrecoverable.
    #
    # Order within the publication matters just as much. @fl_phase is what marks
    # a pane as "in a float", and `toggle` refuses any pane that has one — so a
    # phase written BEFORE the metadata means a death mid-publication leaves the
    # pane at home, wedged, and unfloatable forever. Writing the phase last makes
    # the only interrupted state a pane carrying stray metadata and no phase,
    # which is inert: the next float overwrites it.
    #
    # The holder records the pane it is for, so recovery can find a pane that
    # never moved — nothing else enumerates it, since it is still in its own
    # window rather than in the holder.
    tmux set -t "$holder" @fl_pane "$pane" 2>/dev/null
    set_pane_opt "$pane" @fl_nonce   "$nonce"
    set_pane_opt "$pane" @fl_holder  "$holder"
    set_pane_opt "$pane" @fl_src_sess "$sess"
    set_pane_opt "$pane" @fl_src_win  "$win"
    set_pane_opt "$pane" @fl_src_idx  "$win_idx"
    set_pane_opt "$pane" @fl_src_name "$win_name"
    set_pane_opt "$pane" @fl_order   "$order"
    set_pane_opt "$pane" @fl_layout  "$layout"
    set_pane_opt "$pane" @fl_active  "$active"
    set_pane_opt "$pane" @fl_phase   preparing      # last — see above

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

    # Testing seam: stop with the float staged but never presented — the state a
    # container that died on the spot would leave, which is what the recovery
    # paths exist for and cannot otherwise be observed.
    [ -n "${FLOAT_SKIP_CONTAINER:-}" ] && return 0

    open_container "$holder" "$pane" "$client"

    # Presentation can fail — a bad @float_border, no client to draw on — and a
    # float whose container never opened would otherwise leave the pane sitting
    # in an unattached holder, off screen, with a live phase. Restoring
    # unconditionally covers that: on the normal path the container's own shell
    # has already restored, and restore is idempotent, so this is a no-op.
    restore_pane "$pane"
}

# --- scratch ------------------------------------------------------------------

# `prefix C-z`: an EPHEMERAL shell in a popup, opened at the active pane's
# current directory — poke around next to a running agent without carving a
# pane out of the layout first. Deliberately none of the float's machinery: no
# holder, no state, no resurrect interaction, and no key-table staging either —
# the popup runs a plain shell, not a nested tmux client, so the outer prefix
# surface is never inherited. The popup's lifecycle IS the garbage collection:
# ctrl-d / exit ends the shell, display-popup -E reaps the popup, nothing
# remains. This is the second consumer of the presentation conventions
# (geometry, border validation, title) — see "the container adapter" above for
# why it must NOT share the holder state machine.
#
# SCRATCH_CMD is a testing seam: the suite substitutes a command that records
# its cwd and exits, which is how "opens at the pane's directory" and "leaves
# nothing behind" are asserted without a human watching a popup.
scratch_popup() {
    local pane="$1" client="${2:-}"

    pane_exists "$pane" || { msg "scratch: no such pane"; return 1; }

    local dir
    dir=$(tmux display-message -p -t "$pane" '#{pane_current_path}' 2>/dev/null)
    [ -d "$dir" ] || dir="$HOME"

    local border
    border=$(resolve_border @scratch_border "$SCRATCH_BORDER_DEFAULT")

    # SCRATCH_SRC_PANE rides in so a script run inside the scratch can
    # send-keys back to the pane it was opened from.
    local args=(-E -d "$dir" -w "$SCRATCH_W" -h "$SCRATCH_H" -b "$border"
                -T " scratch · ${dir##*/} " -e SCRATCH_SRC_PANE="$pane")
    [ -n "$client" ] && args+=(-c "$client")

    tmux display-popup "${args[@]}" "${SCRATCH_CMD:-exec ${SHELL:-bash} -il}"
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
    local now mine claim claim_at
    now=$(date +%s); mine="$$:$now"
    if ! tmux set -p -t "$pane" -o @fl_claim "$mine" 2>/dev/null; then
        claim=$(pane_opt "$pane" @fl_claim)
        claim_at=${claim##*:}
        if [ -n "$claim_at" ] && [ $((now - claim_at)) -lt "$FLOAT_CLAIM_TTL" ]; then
            return 0                     # a live restorer owns this pane
        fi
        # STEALING MUST BE AS SERIALIZED AS CLAIMING. A plain overwrite here let
        # every contender that saw the same expired claim take it and proceed,
        # putting two restorers straight back on the corruption path the atomic
        # claim closed. Compare-and-set instead: `if-shell -F` evaluates the
        # condition and queues the set as one unit on the server's command
        # queue, so only the contender whose value survives may continue.
        tmux if-shell -F -t "$pane" "#{==:#{@fl_claim},$claim}" \
            "set-option -p -t '$pane' @fl_claim '$mine'" 2>/dev/null
        [ "$(pane_opt "$pane" @fl_claim)" = "$mine" ] || return 0
    fi

    # Re-read after winning: the state may have been rewritten between our
    # first look and the claim.
    phase=$(pane_opt "$pane" @fl_phase)
    [ -n "$phase" ] || { unset_pane_opt "$pane" @fl_claim; return 0; }
    set_pane_opt "$pane" @fl_phase restoring

    # `preparing` means we died between publishing state and completing the
    # move. Whether the pane actually left is decided by where it is NOW, not by
    # what we recorded — a pane interrupted before its metadata was written has
    # no recorded source window to compare against, and treating that as "moved"
    # sends it down the degraded path, which manufactures a junk recovery
    # session and leaves the pane wedged. A pane outside any marked holder never
    # moved: roll the whole thing back.
    if [ "$phase" = preparing ] && ! pane_in_holder "$pane"; then
        # The holder exists only to receive this pane. If the pane never made it
        # in, the holder's whole content is the placeholder shell we spawned, so
        # drop it rather than leaving it to be surfaced as a junk `recovered-*`
        # session — waiting for it to be *empty* never fires, since the
        # placeholder is only killed after a successful break-pane.
        local h; h=$(pane_opt "$pane" @fl_holder)
        if [ -n "$h" ] && sess_exists "$h" && \
           [ -n "$(tmux show -qv -t "$h" @fl_holder_nonce 2>/dev/null)" ]; then
            tmux kill-session -t "=$h" 2>/dev/null
        fi
        clear_state "$pane"
        reconcile
        return 0
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

    # ...plus any pane carrying a phase while sitting OUTSIDE a holder. That is
    # a float interrupted before its move completed: the pane is still in its
    # own window, so no holder enumerates it, yet the phase makes `toggle`
    # refuse it — leave it and the float is wedged for that pane forever.
    # Scanning panes directly rather than trusting a marker on the holder means
    # this holds however the interruption left the holder.
    local p ph
    while IFS=' ' read -r p ph; do
        [ -n "${ph:-}" ] || continue
        pane_in_holder "$p" || printf '%s\n' "$p"
    done < <(tmux list-panes -a -F '#{pane_id} #{@fl_phase}' 2>/dev/null)
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

        # A holder that never received the pane it was made for holds nothing
        # but the placeholder shell we spawned. Surfacing that as a `recovered-*`
        # session would manufacture junk out of a cleanup; drop it instead.
        local owned; owned=$(tmux show -qv -t "$s" @fl_pane 2>/dev/null)
        if [ -n "$owned" ] && ! printf '%s\n' \
             "$(tmux list-panes -s -t "=$s" -F '#{pane_id}' 2>/dev/null)" \
             | grep -qx "$owned"; then
            tmux kill-session -t "=$s" 2>/dev/null
            continue
        fi
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
    scratch) scratch_popup "${2:?pane required}" "${3:-}" ;;
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
        printf 'usage: %s {toggle|restore|scratch|sweep|prepare-save} ...\n' "${0##*/}" >&2
        exit 64
        ;;
esac
