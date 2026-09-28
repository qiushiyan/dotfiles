#!/usr/bin/env bash
# tmux-rename-pane.sh — label a pane, from a popup text prompt.
#
#   open <pane> [client]   bound to `prefix M` (run-shell -b); opens the popup
#   prompt <pane>          INTERNAL: runs inside the popup
#
# The pane id travels as an ARGUMENT end to end. `display-popup` does not
# expand #{...} in its command argument, so the binding goes through run-shell,
# which does, and this script opens the popup itself — the float's pattern.
# (It used to be stashed in a global env var between the binding and the
# popup, which races when two clients act at once.)
#
# This is a FREE-TEXT field, not a picker: whatever you type is the label, verbatim.
# fzf is here only as a line editor — `--disabled` turns off matching and the input
# list is empty, so there is nothing to select and Enter can only ever return your
# own query. (An earlier version offered directory/branch suggestions as rows; with
# rows present, Enter takes the highlighted row instead of what you typed, which is
# exactly wrong for a name you're inventing. Don't add rows back.)
#
# WHY fzf AND NOT A SHELL PROMPT: fzf owns its key handling, so backspace, ^W, ^U and
# Esc-to-cancel work the same regardless of terminfo or keymap. The first cut used
# zsh `vared` and was unusable — a non-interactive shell never reads .zshrc, zsh picks
# vi bindings whenever $EDITOR matches *vi* (nvim does), and in viins ^? is
# vi-backward-delete-char, which refuses to delete past the point where insert mode
# began: a prefilled label could only be APPENDED to, and Esc just switched to command
# mode. Don't reintroduce a shell line-editor here.
#
#   Enter  -> apply what's typed; empty (^U first) resets the pane to the program's
#             own title: label cleared, allow-set-title back to inherit, border
#             reconciled — off only when no pane in the window still needs it
#   Esc    -> cancel, pane untouched
set -uo pipefail

# shellcheck source=lib/tmux-common.sh
. "${BASH_SOURCE[0]%/*}/lib/tmux-common.sh"

SELF="$HOME/.config/tmux/scripts/tmux-rename-pane.sh"

die() { printf '\n  %s\n' "$*" >&2; sleep 1.8; exit 1; }

valid_pane() { case "${1:-}" in %[0-9]*) return 0 ;; esac; return 1; }

# 60x5 = a 58x3 interior: prompt line, hint line, and no wasted space. The
# frame is the global popup-border-lines (rounded), like every transient dialog.
open_popup() {
    local pane="$1" client args
    valid_pane "$pane" && pane_exists "$pane" || { msg "rename: no such pane"; return 1; }
    args=(-E -w 60 -h 5 -T ' rename pane ')
    client=$(live_client "${2:-}")
    [ -n "$client" ] && args+=(-c "$client")
    tmux display-popup "${args[@]}" "exec bash '$SELF' prompt '$pane'"
}

prompt() {
    local pane="$1" current label st
    valid_pane "$pane" || die "couldn't determine the pane (got: '${pane}')"

    # Prefill with the label only if it's YOURS. Naming a pane sets allow-set-title off
    # on it (see tmux.conf), so that option doubles as a reliable "is this label mine?"
    # flag — without it we'd prefill the hostname, or whatever status the program
    # inside last painted over the title.
    current=$(pane_fmt "$pane" '#{?allow-set-title,,#{pane_title}}')

    # --print-query is the whole point: it echoes the typed line. Exit 130 is Esc/^C;
    # with no list to match against, Enter exits 1 and still prints the query.
    label=$(: | fzf \
              --print-query --disabled --no-mouse --no-info --no-separator \
              --prompt='pane title > ' \
              --header='Enter apply · empty clears · Esc cancel' \
              --query="$current" \
              --height=100% --reverse --border=none)
    st=$?
    [ "$st" = 130 ] && return 0

    label=$(printf '%s' "$label" | sed -n 1p)

    # trim surrounding whitespace; a blank label means "reset"
    label="${label#"${label%%[![:space:]]*}"}"
    label="${label%"${label##*[![:space:]]}"}"

    if [ -z "$label" ]; then
        tmux select-pane -t "$pane" -T ""
        tmux set-option -p -u -t "$pane" allow-set-title
        # border OFF is owned by the reconciler: it keeps the row when another pane
        # in the window is still named or shows agent status (see tmux.conf)
        bash "$AGENT_STATUS" reconcile "$pane"
    else
        tmux set-option -w -t "$pane" pane-border-status top
        tmux set-option -p -t "$pane" allow-set-title off
        tmux select-pane -t "$pane" -T "$label"
    fi
}

case "${1:-}" in
    open)   open_popup "${2:-}" "${3:-}" ;;
    prompt) prompt "${2:-}" ;;
    *) printf 'usage: %s {open <pane> [client]|prompt <pane>}\n' "${0##*/}" >&2; exit 64 ;;
esac
