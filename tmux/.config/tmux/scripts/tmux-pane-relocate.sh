#!/usr/bin/env bash
# tmux-pane-relocate.sh — the moving verbs behind `prefix p` pane mode.
#
# ONE RULE for h/j/k/l: **push the pane that way. If something is there, trade
# places. If nothing is there, become the wall.** Pushing the bottom pane of a
# vertical split to the right makes it the full-height right-hand column; in a
# side-by-side split, pushing left swaps the two panes. Same key, two
# behaviours, and you never have to know which one you are invoking.
#
#   push <left|right|up|down> [pane]   the rule above
#   hold [pane]                        pick the pane up for a later put
#   put [target-pane]                  place the held pane in target's window
#   release                            drop the hold
#   pick <pane> <client>               popup: choose a window, place <pane> there
#   break [pane]                       break-pane, with the journal invalidated
#   undo [window]                      undo the last PUSH in this window
#   pick-ui / preview / targets        INTERNAL: the picker popup's parts
#
# CROSS-WINDOW MOVES ARE HOLD → WALK → PUT. `hold` records ONE pane id in the
# global option @pane_hold (plus a display label in @pane_hold_label) and the
# user then navigates with their ordinary window keys; `put` places the held
# pane in the window the user is looking at. The state is deliberately a private
# option and not tmux's mark: the mark is server-global and replaced by any
# `select-pane -m` from any client, and its presence silently flips the default
# SOURCE of move-pane (see the note in place()). The pane id is
# the only authoritative field — the source window is history the operation
# never needs, and after a resurrect restore both would be stale anyway; a
# stale id simply renders as "gone" on the next put.
#
# `pick` is the visual front end: the same placement, with the target chosen
# from a popup instead of by walking. It carries its SOURCE PANE AS AN ARGUMENT
# captured before the popup opens and never reads @pane_hold — the popup blocks
# for as long as the user browses, and another client can hold a different pane
# meanwhile; a pick that re-read the slot on Enter would move that other pane.
#
# `undo` is deliberately scoped to pushes. A cross-window move is not
# journalled: it can destroy the window an undo record would live on, and the
# (pane order, layout) record cannot describe a move between two windows.
# Recording it properly means a cross-window move transaction — a much larger
# feature than this mode needs. What a move DOES do to the journal is
# invalidate it: after `put` or `break` the source and destination windows no
# longer hold the pane set any of their records describe, and journal_pop
# refuses (and keeps) a mismatched record — so without invalidation `u` would
# reach that record and refuse forever. place() clears both journals.
#
# WHY THE EDGE GUARD IS MANDATORY, NOT A REFINEMENT. tmux's directional targets
# WRAP: with two side-by-side panes, `{left-of}` from the LEFTMOST pane resolves
# to the rightmost one (verified). So a naive `swap-pane -t '{left-of}'` — what
# tmux-tilish does — silently swaps with the pane on the opposite side when you
# push at an edge. #{pane_at_<dir>} is what distinguishes "there is a neighbour
# that way" from "I am against that wall", and it must be checked first.
#
# UNDO IS NOT select-layout -o. That undoes the last *geometry* change, but a
# neighbour swap changes pane IDENTITY without changing geometry, so -o cannot
# reverse a push — and replaying a layout string has the same identity blindness
# (the string addresses panes by index order). The journal below records the
# ordered pane ids AND the layout before every push, which is the only pair
# that reconstructs a move.
#
# Native floating panes (tmux 3.7 `prefix *`) are rejected: they cannot be
# swapped ("cannot swap floating panes"), they are counted by #{window_panes},
# and they are embedded in #{window_layout} — so every list and comparison here
# filters on #{pane_floating_flag}.

set -uo pipefail

CLAUDE_CTX="$HOME/.config/tmux/scripts/tmux-claude-ctx.sh"
JOURNAL_DEPTH=20

msg() { tmux display-message "$*" 2>/dev/null || true; }

tiled_panes() {
    tmux list-panes -t "$1" -f '#{==:#{pane_floating_flag},0}' -F '#{pane_id}' 2>/dev/null
}
# Non-empty output, not the exit status: tmux 3.7b exits 0 for a target that
# no longer exists and prints nothing (verified) — an rc check calls every dead
# pane alive.
pane_exists() { [ -n "$(tmux display-message -p -t "$1" '#{pane_id}' 2>/dev/null)" ]; }
win_exists()  { [ -n "$(tmux display-message -p -t "$1" '#{window_id}' 2>/dev/null)" ]; }
reconcile()   { TMUX_PANE= bash "$CLAUDE_CTX" reconcile >/dev/null 2>&1 || true; }
pane_fmt()    { tmux display-message -p -t "$1" "$2" 2>/dev/null; }

SELF="$HOME/.config/tmux/scripts/tmux-pane-relocate.sh"

# Why a pane cannot be moved between windows, as a word — or nothing when it
# can. Native floats (tmux 3.7 `prefix *`) have no tiled slot to move to and
# cannot be returned to one. A pane mid-float under tmux-float-pane.sh
# (`prefix z`) is sitting in a `_float_*` holder session with restore metadata
# on it: moving it from there would bypass the float's restore transaction and
# leave the container restoring a pane that has already gone elsewhere. The
# phase option is the normal signal; the holder-session check holds the
# invariant for a pane whose options were lost mid-clear.
unmovable_reason() {
    local pane="$1" sess
    pane_exists "$pane" || { printf 'gone'; return; }
    [ "$(pane_fmt "$pane" '#{pane_floating_flag}')" = 1 ] && { printf 'native-float'; return; }
    [ -n "$(tmux show -pqv -t "$pane" @fl_phase 2>/dev/null)" ] && { printf 'floated'; return; }
    sess=$(pane_fmt "$pane" '#{session_name}')
    [ -n "$sess" ] && [ -n "$(tmux show -qv -t "$sess" @fl_holder_nonce 2>/dev/null)" ] && { printf 'floated'; return; }
    printf ''
}

journal_clear() { tmux set -w -u -t "$1" @pane_journal 2>/dev/null || true; }

# --- journal ------------------------------------------------------------------
# Per-window stack in a window option. Records are "order<TAB>layout", newest
# first, newline separated, depth-capped.

journal_push() {
    local win="$1" rec cur
    rec="$(tiled_panes "$win" | tr '\n' ' ')	$(tmux display-message -p -t "$win" '#{window_layout}')"
    cur=$(tmux show -wqv -t "$win" @pane_journal 2>/dev/null)
    tmux set -w -t "$win" @pane_journal \
        "$(printf '%s\n%s' "$rec" "$cur" | grep -v '^$' | head -n "$JOURNAL_DEPTH")" 2>/dev/null
}

journal_pop() {
    local win="$1" cur rec rest order layout i=0 want have
    cur=$(tmux show -wqv -t "$win" @pane_journal 2>/dev/null)
    [ -n "$cur" ] || { msg "pane: nothing to undo"; return 0; }
    rec=$(printf '%s' "$cur" | head -1)
    rest=$(printf '%s' "$cur" | tail -n +2)
    order=${rec%%	*}
    layout=${rec#*	}

    # VALIDATE BEFORE CONSUMING. A push neither adds nor removes panes, so the
    # record only applies while the window still holds exactly the same set. If
    # a pane has since died or been split, replaying it would half-apply — swap
    # some panes, skip the missing ones, then silently ignore a failed layout —
    # and the record would be gone either way. Refuse and keep it instead.
    local now_set rec_set
    now_set=$(tiled_panes "$win" | sort | tr '\n' ' ')
    rec_set=$(printf '%s\n' $order | sort | tr '\n' ' ')
    if [ "$now_set" != "$rec_set" ]; then
        msg "pane: can't undo — the panes changed since that move"
        return 0
    fi

    tmux set -w -t "$win" @pane_journal "$rest" 2>/dev/null

    for want in $order; do
        pane_exists "$want" || { i=$((i + 1)); continue; }
        have=$(tiled_panes "$win" | sed -n "$((i + 1))p")
        [ -n "$have" ] && [ "$have" != "$want" ] && \
            tmux swap-pane -d -s "$want" -t "$have" 2>/dev/null
        i=$((i + 1))
    done
    [ -n "$layout" ] && tmux select-layout -t "$win" "$layout" 2>/dev/null
    reconcile
}

# --- push ---------------------------------------------------------------------

push() {
    local dir="$1" pane="${2:-}"
    [ -n "$pane" ] || pane=$(tmux display-message -p '#{pane_id}')
    pane_exists "$pane" || return 0

    if [ "$(tmux display-message -p -t "$pane" '#{pane_floating_flag}')" = 1 ]; then
        msg "pane: floating panes cannot be moved with the keyboard yet"; return 0
    fi

    local win; win=$(tmux display-message -p -t "$pane" '#{window_id}')
    local n;   n=$(tiled_panes "$win" | wc -l | tr -d ' ')
    [ "$n" -lt 2 ] && { msg "pane: only one pane in this window"; return 0; }

    # Geometry flags, read in one round trip.
    local at_left at_right at_top at_bottom
    IFS=' ' read -r at_left at_right at_top at_bottom < <(tmux display-message -p -t "$pane" \
        '#{pane_at_left} #{pane_at_right} #{pane_at_top} #{pane_at_bottom}')

    local at_edge target_of flags spans
    case "$dir" in
        left)  at_edge=$at_left;   target_of='{left-of}';  flags='-h -b'
               spans=$(( at_top == 1 && at_bottom == 1 ? 1 : 0 )) ;;
        right) at_edge=$at_right;  target_of='{right-of}'; flags='-h'
               spans=$(( at_top == 1 && at_bottom == 1 ? 1 : 0 )) ;;
        up)    at_edge=$at_top;    target_of='{up-of}';    flags='-v -b'
               spans=$(( at_left == 1 && at_right == 1 ? 1 : 0 )) ;;
        down)  at_edge=$at_bottom; target_of='{down-of}';  flags='-v'
               spans=$(( at_left == 1 && at_right == 1 ? 1 : 0 )) ;;
        *) return 64 ;;
    esac

    if [ "$at_edge" != 1 ]; then
        # There is a neighbour that way — trade places. Guarded by at_edge, so
        # the wrap-around case can never be reached here.
        local other; other=$(tmux display-message -p -t "$target_of" '#{pane_id}' 2>/dev/null)
        [ -n "$other" ] && [ "$other" != "$pane" ] || return 0
        journal_push "$win"
        tmux swap-pane -d -s "$pane" -t "$other" 2>/dev/null
        tmux select-pane -t "$pane" 2>/dev/null
    else
        # Against that wall already. Becoming the wall is only meaningful if we
        # are not already the full-span pane on it — re-running the relocation
        # would churn pane order for no visible change.
        if [ "$spans" = 1 ]; then
            msg "pane: already the full ${dir} edge"; return 0
        fi
        local sibling
        sibling=$(tiled_panes "$win" | grep -v "^$pane$" | head -1)
        [ -n "$sibling" ] || return 0
        journal_push "$win"
        # shellcheck disable=SC2086
        tmux move-pane -f $flags -s "$pane" -t "$sibling" 2>/dev/null || {
            msg "pane: could not move to the ${dir} edge"; return 0; }
        tmux select-pane -t "$pane" 2>/dev/null
    fi
    reconcile
}

# --- place: the one cross-window move -----------------------------------------
# Everything that moves a pane into another window goes through here — put and
# pick are two ways of choosing the arguments. Lands the pane as the full-height
# RIGHT-hand column of the target's window (`-f -h`, the same relocation push
# uses for "become the wall"): with one pane there it is the ordinary two-column
# split, with several it is a predictable staging wall that the very next
# h/j/k push places. Splitting the focused pane instead would make the landing
# depend on incidental focus and could nest a small split. Then selects the
# window and the pane, clears both windows' journals, and reconciles borders
# (the move strands border state on both ends).

place() { # <source pane> <target pane>
    local src="$1" tgt="$2" src_win tgt_win
    src_win=$(pane_fmt "$src" '#{window_id}'); tgt_win=$(pane_fmt "$tgt" '#{window_id}')
    [ -n "$src_win" ] && [ -n "$tgt_win" ] || return 1

    # -s IS MANDATORY. move-pane with -s omitted and a mark present uses THE
    # MARKED PANE as the source (man tmux: "If -s is omitted and a marked pane
    # is present ... the marked pane is used rather than the current pane") —
    # i.e. it performs a different move than the one asked for.
    tmux move-pane -f -h -s "$src" -t "$tgt" 2>/dev/null || return 1
    tmux select-window -t "$tgt_win" 2>/dev/null
    tmux select-pane -t "$src" 2>/dev/null
    journal_clear "$tgt_win"
    win_exists "$src_win" && journal_clear "$src_win"
    reconcile
}

# The pane a put lands next to: the target window's active pane, unless that
# is a native float (they can be active) — then the first tiled pane, so the
# landing never targets something that has no tiled slot.
tiled_target_in() { # <window>
    local active
    active=$(tmux list-panes -t "$1" -f '#{&&:#{pane_active},#{==:#{pane_floating_flag},0}}' -F '#{pane_id}' 2>/dev/null | head -1)
    [ -n "$active" ] && { printf '%s' "$active"; return; }
    tiled_panes "$1" | head -1
}

# --- hold / put / release -----------------------------------------------------

held()       { tmux show -gqv @pane_hold 2>/dev/null; }
clear_hold() { tmux set -gu @pane_hold 2>/dev/null; tmux set -gu @pane_hold_label 2>/dev/null; }

hold() {
    local pane="${1:-}" why label
    [ -n "$pane" ] || pane=$(tmux display-message -p '#{pane_id}')
    # A refused hold leaves any existing hold alone: the user still has what
    # they picked up before.
    why=$(unmovable_reason "$pane")
    case "$why" in
        gone)         return 0 ;;
        native-float) msg "pane: a floating pane cannot be moved between windows"; return 0 ;;
        floated)      msg "pane: close the float first (prefix z)"; return 0 ;;
    esac
    # Display label, snapshotted now: what was picked up, and where it was.
    # Same title rule as the float and the border: a title equal to the
    # hostname is tmux's unset default, so show the command instead.
    label=$(pane_fmt "$pane" '#{?#{==:#{pane_title},#{host}},#{pane_current_command},#{pane_title}} · window #{window_index}')
    tmux set -g @pane_hold "$pane" 2>/dev/null
    tmux set -g @pane_hold_label "$label" 2>/dev/null
    msg "pane: holding $label — go to a window and press prefix p p"
}

release() {
    [ -n "$(held)" ] && msg "pane: released" || msg "pane: nothing held"
    clear_hold
}

put() {
    local target="${1:-}" pane why tgt_win
    [ -n "$target" ] || target=$(tmux display-message -p '#{pane_id}')
    pane=$(held)
    [ -n "$pane" ] || { msg "pane: nothing held (g on a pane picks it up)"; return 0; }

    # Re-validate now: the hold may be any age. Which refusals CLEAR the hold
    # and which keep it is the point of this block. Gone (killed, or its id
    # reused after a resurrect restore) and native-floated can never be put,
    # so the hold is cleared. Floated by prefix z is temporary — keep the hold,
    # so closing the float makes it usable again.
    why=$(unmovable_reason "$pane")
    case "$why" in
        gone)         clear_hold; msg "pane: the held pane is gone"; return 0 ;;
        native-float) clear_hold; msg "pane: the held pane is now a floating pane — released"; return 0 ;;
        floated)      msg "pane: the held pane is in a float — close it first (prefix z)"; return 0 ;;
    esac

    tgt_win=$(pane_fmt "$target" '#{window_id}')
    [ -n "$tgt_win" ] || return 0
    if [ "$(pane_fmt "$pane" '#{window_id}')" = "$tgt_win" ]; then
        clear_hold; msg "pane: already in this window — released"; return 0
    fi
    # The pane we land beside must have a tiled slot; a native float being
    # active is refused rather than silently targeting whatever is behind it.
    if [ "$(pane_fmt "$target" '#{pane_floating_flag}')" = 1 ]; then
        msg "pane: close the floating pane first"; return 0
    fi

    if place "$pane" "$target"; then
        # Clear only if the slot still names the pane THIS put consumed — a
        # newer hold made meanwhile (another client) must not be erased.
        [ "$(held)" = "$pane" ] && clear_hold
    else
        msg "pane: move failed"        # hold retained for a retry
    fi
}

# --- break --------------------------------------------------------------------
# break-pane, plus the journal invalidation place() does: the source window's
# records describe a pane set it no longer has.

break_pane() {
    local pane="${1:-}" win
    [ -n "$pane" ] || pane=$(tmux display-message -p '#{pane_id}')
    win=$(pane_fmt "$pane" '#{window_id}')
    [ -n "$win" ] || return 0
    journal_clear "$win"
    tmux break-pane -s "$pane" 2>/dev/null
    reconcile
}

# --- pick: the popup front end ------------------------------------------------
# `pick` opens the popup on the user's client and returns (display-popup blocks
# its issuing command, so the binding calls this with run-shell -b). `pick-ui`
# runs INSIDE the popup: fzf over the other windows of the pane's session, a
# preview of the highlighted window, and Enter places the source pane there.
# Windows of THIS session only, and never the source window: placement needs
# nothing finer than a window (`-f -h` takes any tiled pane), and another
# session is a walk away with the hold. The pick re-enters pane mode itself on
# every exit path, so the binding must not — the popup would otherwise be up
# while the table is already set.

pick() {
    local pane="${1:-}" client="${2:-}" why others
    [ -n "$pane" ] || pane=$(tmux display-message -p '#{pane_id}')
    why=$(unmovable_reason "$pane")
    case "$why" in
        gone)         return 0 ;;
        native-float) msg "pane: a floating pane cannot be moved between windows"; return 0 ;;
        floated)      msg "pane: close the float first (prefix z)"; return 0 ;;
    esac
    others=$(other_windows "$pane" | wc -l | tr -d ' ')
    if [ "$others" = 0 ]; then
        msg "pane: no other window in this session (b breaks it into a new one)"
        reenter "$client"; return 0
    fi
    local args=(-E -w 72% -h 60% -b "$(popup_border)" -T ' move pane to ')
    [ -n "$client" ] && tmux display-message -p -c "$client" '' >/dev/null 2>&1 && args+=(-c "$client")
    tmux display-popup "${args[@]}" "exec bash '$SELF' pick-ui '$pane' '$client'"
}

reenter() { # <client> — back into pane mode on the client that started the pick
    [ -n "${1:-}" ] || return 0
    tmux switch-client -c "$1" -T panes 2>/dev/null || true
    tmux refresh-client -S -t "$1" 2>/dev/null || true   # redraw the cheat sheet row now
}

popup_border() {
    local b; b=$(tmux show -gqv @float_border 2>/dev/null)
    case "$b" in single|rounded|double|heavy|simple|padded|none) printf '%s' "$b" ;; *) printf 'rounded' ;; esac
}

# "<window_id>\t<index>: <name>  · <n> pane(s)" for every other window of the
# pane's session. The id is the hidden key; names and indices are display only.
other_windows() { # <pane>
    local win sess
    win=$(pane_fmt "$1" '#{window_id}'); sess=$(pane_fmt "$1" '#{session_id}')
    tmux list-windows -t "$sess" -f "#{!=:#{window_id},$win}" \
        -F '#{window_id}	#{window_index}: #{window_name}  · #{window_panes} pane#{?#{==:#{window_panes},1},,s}' 2>/dev/null
}

pick_ui() {
    local pane="$1" client="${2:-}" sel win target
    local fzf_colors="fg+:-1" accent muted dim surface green red
    # fzf colours from the live tmux palette — same trick as the worktree popup.
    accent=$(tmux show -gqv @thm_mauve 2>/dev/null)
    if [ -n "$accent" ]; then
        muted=$(tmux show -gqv @thm_overlay_2); dim=$(tmux show -gqv @thm_overlay_0)
        surface=$(tmux show -gqv @thm_surface_0); green=$(tmux show -gqv @thm_green)
        red=$(tmux show -gqv @thm_red)
        fzf_colors="hl:$red,hl+:$red,fg+:-1,bg+:$surface,gutter:-1,query:-1,pointer:$accent,prompt:$accent,spinner:$accent,marker:$green,info:$muted,header:$muted,label:$muted,border:$dim,preview-border:$dim"
    fi
    sel=$(other_windows "$pane" | fzf --ansi --no-sort --delimiter '	' --with-nth 2 \
        --prompt '⇢  ' --header '  enter move here · esc cancel' \
        --color "$fzf_colors" --layout reverse \
        --preview "bash '$SELF' preview {1}" --preview-window 'right,60%,border-left' \
        --bind 'tab:down,btab:up')
    win=${sel%%	*}
    if [ -z "$win" ]; then reenter "$client"; return 0; fi        # cancelled: nothing moves
    target=$(tiled_target_in "$win")
    [ -n "$target" ] || { msg "pane: that window has no tiled pane"; reenter "$client"; return 0; }
    # The source is the argument captured before the popup opened — never the
    # hold slot, which another client may have changed while this was open.
    if ! place "$pane" "$target"; then msg "pane: move failed"; fi
    reenter "$client"
}

# The preview: what is in that window, so the choice is made without walking
# there. Inventory of tiled panes (active one marked), then the tail of the
# active pane's screen.
preview() { # <window_id>
    local win="$1" active
    tmux display-message -p -t "$win" '#{window_index}: #{window_name}' 2>/dev/null
    echo
    tmux list-panes -t "$win" -f '#{==:#{pane_floating_flag},0}' \
        -F '#{?pane_active,▶,·} #{?#{==:#{pane_title},#{host}},#{pane_current_command},#{pane_title}}  #{pane_width}x#{pane_height}  #{s|^'"$HOME"'|~|:#{pane_current_path}}' 2>/dev/null
    active=$(tiled_target_in "$win")
    [ -n "$active" ] || return 0
    echo; printf -- '─────\n'
    tmux capture-pane -p -t "$active" 2>/dev/null \
        | awk '{ l[NR] = $0 } END { n = NR; while (n > 0 && l[n] == "") n--; for (i = 1; i <= n; i++) print l[i] }' \
        | tail -n 40
}

case "${1:-}" in
    push)    push "${2:?direction required}" "${3:-}" ;;
    hold)    hold "${2:-}" ;;
    put)     put "${2:-}" ;;
    release) release ;;
    pick)    pick "${2:-}" "${3:-}" ;;
    pick-ui) pick_ui "${2:?pane required}" "${3:-}" ;;
    preview) preview "${2:?window required}" ;;
    targets) other_windows "${2:?pane required}" ;;
    break)   break_pane "${2:-}" ;;
    undo)    journal_pop "${2:-$(tmux display-message -p '#{window_id}')}" ;;
    *) printf 'usage: %s {push <dir>|hold|put|release|pick|break|undo} [target]\n' "${0##*/}" >&2; exit 64 ;;
esac
