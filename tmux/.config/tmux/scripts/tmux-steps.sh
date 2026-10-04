#!/usr/bin/env bash
# tmux-steps.sh — the session board: what has run in every Claude session on
# this machine, with a note field. See steps.md beside this file.
#
#   open <pane> [client]     bound to `prefix S` (run-shell -b); opens the popup
#   pick <pane> [client]     INTERNAL: the board, inside the popup
#   board                    INTERNAL: the board's rows, for the list
#   preview <session>        INTERNAL: one session, for the preview pane
#   toggle                   INTERNAL: the actions that flip the preview
#   note <session>           INTERNAL: a one-line note for that session
#
# Every line it shows comes from `claude-steps` (~/dev/claude-steps), which
# reads the sessions' transcript files. Nothing here writes to a session or
# sends keys to a pane: the board is for reading, and the only state it
# changes is the notes file and which pane the client shows.
#
# The binary paints and fits what it prints when it is told to. fzf reads it
# through a pipe, so every call asks for colour (CLICOLOR_FORCE) and gives the
# width it has (COLUMNS); `board` and `preview` are the two places that do.
#
# The pane id travels as an ARGUMENT end to end, the rename popup's pattern:
# `display-popup` does not expand #{...} in its command, so the binding goes
# through run-shell, which does, and this script opens the popup itself.
#
# A row is `<pane id> TAB <session id> TAB <text>`. The preview and the note
# use the SESSION id on the row, not the pane: a pane can move to another
# session (/clear, /resume) while the popup is open, and a note typed against
# a row belongs to the session that row showed.
#
#   Enter   -> switch to the row's pane
#   Tab     -> flip the preview between the session's steps and its history
#   ctrl-n  -> write a note for the row's session
#   Esc     -> close
set -uo pipefail

# shellcheck source=lib/tmux-common.sh
. "${BASH_SOURCE[0]%/*}/lib/tmux-common.sh"

SELF="${BASH_SOURCE[0]}"
STEPS=${CLAUDE_STEPS_BIN:-claude-steps}

die() { printf '\n  %s\n' "$*" >&2; sleep 1.8; exit 1; }

valid_pane() { case "${1:-}" in %[0-9]*) return 0 ;; esac; return 1; }

open_popup() {
    local pane="$1"
    # Status 0 after msg: run-shell would replace the message with "returned 1".
    valid_pane "$pane" && pane_exists "$pane" || { msg "steps: no such pane"; return 0; }
    command -v "$STEPS" >/dev/null 2>&1 || { msg "steps: claude-steps is not installed (make install in ~/dev/claude-steps)"; return 0; }
    popup "${2:-}" -E -w 92% -h 88% -T ' sessions ' "exec bash '$SELF' pick '$pane' '${2:-}'"
}

# The list's rows, cut to the width fzf gives a row: FZF_COLUMNS inside fzf,
# the terminal's width before it starts, less the three columns fzf keeps for
# its pointer and its scrollbar. A row fzf has to cut loses its right end,
# which is where the note is. With no width the binary cuts nothing.
board() {
    local cols=${FZF_COLUMNS:-}
    [ -n "$cols" ] || cols=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2)
    CLICOLOR_FORCE=1 COLUMNS=$(( ${cols:-0} - 3 )) "$STEPS" board --ids
}

# One session for the preview pane: its labels, notes and steps, or with the
# pane labelled "history" its whole timeline. The label is the toggle's state.
preview() {
    local all=''
    case "${FZF_PREVIEW_LABEL:-}" in *history*) all=--all ;; esac
    CLICOLOR_FORCE=1 COLUMNS=${FZF_PREVIEW_COLUMNS:-0} "$STEPS" show ${all:+"$all"} "$1" 2>&1
}

toggle() {
    case "${FZF_PREVIEW_LABEL:-}" in
        *history*) printf 'change-preview-label( steps )+refresh-preview' ;;
        *) printf 'change-preview-label( history )+refresh-preview' ;;
    esac
}

pick() {
    local origin="$1" client="${2:-}" rows err pos out st pane session c
    command -v "$STEPS" >/dev/null 2>&1 || die "claude-steps is not installed"

    err=$(mktemp "${TMPDIR:-/tmp}/tmux-steps.XXXXXX") || die "cannot make a temporary file"
    # shellcheck disable=SC2064  # expand now: err is local
    trap "rm -f '$err'" EXIT
    rows=$(board 2>"$err") || die "$(cat "$err")"
    [ -n "$rows" ] || die "no tmux pane runs a Claude session"

    # Start on the pane the key was pressed in. The header is line 1, so a
    # pane on line N is item N-1.
    pos=$(printf '%s\n' "$rows" | awk -F'\t' -v p="$origin" 'NR > 1 && $1 == p { print NR - 1; exit }')

    # The reload keeps fzf's cursor where it is, so `load` positions it once
    # and then lets go; a note must not throw the cursor back to the origin.
    # The preview opens at its top, where the session's labels are: it does
    # not follow its output down.
    out=$(printf '%s\n' "$rows" | fzf \
            --ansi --delimiter='\t' --with-nth=3 --header-lines=1 \
            --no-multi --no-sort --no-mouse --reverse --border=none --info=inline-right \
            --prompt='session > ' \
            --header='enter switch · tab history · ctrl-n note · ctrl-d/u scroll · esc close' \
            --preview="bash '$SELF' preview {2}" \
            --preview-window='down,62%,wrap,border-top' --preview-label=' steps ' \
            --bind='ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
            --bind="tab:transform(bash '$SELF' toggle)" \
            --bind="load:pos(${pos:-1})+unbind(load)" \
            --bind="ctrl-n:execute(bash '$SELF' note {2})+reload(bash '$SELF' board 2>/dev/null)+refresh-preview" \
            --color="$(fzf_colors_from_palette)")
    st=$?
    [ "$st" = 0 ] || return 0

    pane=${out%%$'\t'*}
    session=${out#*$'\t'}; session=${session%%$'\t'*}
    valid_pane "$pane" && pane_exists "$pane" || die "that pane is gone (session ${session%%-*})"
    c=$(live_client "$client")
    if [ -n "$c" ]; then tmux switch-client -c "$c" -t "$pane"; else tmux switch-client -t "$pane"; fi
}

# A FREE-TEXT field: fzf as a line editor, as in tmux-rename-pane.sh (a shell
# line editor does not edit inside a popup). The session id is an argument to
# claude-steps and `--` ends its options, so a note may start with a dash.
note() {
    local session="$1" text st
    text=$(: | fzf \
             --print-query --disabled --no-mouse --no-info --no-separator \
             --prompt='note > ' \
             --header="for session ${session%%-*} · Enter save · Esc cancel" \
             --height=100% --reverse --border=none)
    st=$?
    [ "$st" = 130 ] && return 0

    text=$(printf '%s' "$text" | sed -n 1p)
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    [ -n "$text" ] || return 0

    "$STEPS" note "$session" -- "$text" || die "the note was not saved"
}

case "${1:-}" in
    open) open_popup "${2:-}" "${3:-}" ;;
    pick) pick "${2:-}" "${3:-}" ;;
    board) board ;;
    preview) preview "${2:-}" ;;
    toggle) toggle ;;
    note) note "${2:-}" ;;
    *) printf 'usage: %s {open <pane> [client]|pick <pane> [client]|board|preview <session>|toggle|note <session>}\n' "${0##*/}" >&2; exit 64 ;;
esac
