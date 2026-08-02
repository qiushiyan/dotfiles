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
#   marked [pane]                      move the pane to the marked pane
#   undo [window]                      undo the last PUSH in this window
#
# `undo` is deliberately scoped to pushes. `marked` is not journalled: a
# cross-window move can destroy the window an undo record would live on, and
# the (pane order, layout) record cannot describe a move between two windows.
# Recording it properly means a cross-window move transaction — a much larger
# feature than this mode needs, and one nothing has asked for.
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
pane_exists() { tmux display-message -p -t "$1" '#{pane_id}' >/dev/null 2>&1; }
reconcile()   { TMUX_PANE= bash "$CLAUDE_CTX" reconcile >/dev/null 2>&1 || true; }

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

# --- marked -------------------------------------------------------------------

move_to_marked() {
    local pane="${1:-}"
    [ -n "$pane" ] || pane=$(tmux display-message -p '#{pane_id}')

    # The mark is SERVER-global, not per-client, and can be replaced between
    # the mark and the move. Re-resolve it here, immediately before using it.
    local marked
    marked=$(tmux display-message -p -t '{marked}' '#{pane_id}' 2>/dev/null) || marked=""
    [ -n "$marked" ] || { msg "pane: no marked pane (press m to mark one)"; return 0; }
    [ "$marked" = "$pane" ] && { msg "pane: that is the marked pane"; return 0; }
    pane_exists "$marked" || { msg "pane: the marked pane is gone"; return 0; }

    # -s IS MANDATORY. join-pane/move-pane with -s omitted and a mark present
    # uses THE MARKED PANE as the source (man tmux: "If -s is omitted and a
    # marked pane is present ... the marked pane is used rather than the
    # current pane") — i.e. it performs the exact opposite move.
    if tmux move-pane -s "$pane" -t "$marked" 2>/dev/null; then
        tmux select-pane -M 2>/dev/null          # clear the mark, but only on success
        tmux select-pane -t "$pane" 2>/dev/null
        reconcile                                 # both windows changed
    else
        msg "pane: move failed"
    fi
}

case "${1:-}" in
    push)   push "${2:?direction required}" "${3:-}" ;;
    marked) move_to_marked "${2:-}" ;;
    undo)   journal_pop "${2:-$(tmux display-message -p '#{window_id}')}" ;;
    *) printf 'usage: %s {push <dir>|marked|undo} [target]\n' "${0##*/}" >&2; exit 64 ;;
esac
