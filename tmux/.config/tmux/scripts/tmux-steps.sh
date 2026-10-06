#!/usr/bin/env bash
# tmux-steps.sh — one Claude session's steps, beside every Claude session on
# this machine, with a note field. See steps.md beside this file.
#
#   open <pane> [client]     bound to `prefix S` (run-shell -b); opens the popup
#   pick <pane> [client]     INTERNAL: the view, inside the popup
#   board                    INTERNAL: the sessions' rows, for the list
#   status <session>         INTERNAL: one session's status and labels, for the side
#   preview <session>        INTERNAL: one session's steps, for the main panel
#   loaded <position>        INTERNAL: the actions after the list loads
#   toggle                   INTERNAL: the actions that flip the main panel
#   note <session>           INTERNAL: a one-line note for that session
#
# Every line it shows comes from `claude-steps` (~/dev/claude-steps), which
# reads the sessions' transcript files. Nothing here writes to a session or
# sends keys to a pane: the view is for reading, and the only state it
# changes is the notes file and which pane the client shows.
#
# The layout is lazygit's. The main panel, on the right, is the session's
# steps, newest first: the popup is opened to read the session the key was
# pressed in. The side column holds that session's status (its directory,
# branch, compactions and pull requests, then each label's latest event and
# the notes) above the list of sessions, which is for the occasional switch.
# A popup narrower than WIDE or shorter than TALL stacks instead: the main
# panel on top is the whole session view, the status first and whole, with
# the steps under it, and the list is under the panel.
#
# The binary paints and fits what it prints when it is told to. fzf reads it
# through a pipe, so every call asks for colour (CLICOLOR_FORCE) and gives the
# width it has (COLUMNS). The side column's width is fixed when the popup
# opens and exported as STEPS_SIDE, so the list and the status are cut to the
# width the column shows; the main panel's is fzf's own.
#
# The pane id travels as an ARGUMENT end to end, the rename popup's pattern:
# `display-popup` does not expand #{...} in its command, so the binding goes
# through run-shell, which does, and this script opens the popup itself.
#
# A row is `<pane id> TAB <session id> TAB <text>`. The status, the steps and
# the note use the SESSION id on the row, not the pane: a pane can move to
# another session (/clear, /resume) while the popup is open, and a note typed
# against a row belongs to the session that row showed.
#
#   Enter   -> switch to the row's pane
#   Tab     -> flip the main panel between the session's steps and its history
#   ctrl-n  -> write a note for the row's session
#   Esc     -> close
set -uo pipefail

# shellcheck source=lib/tmux-common.sh
. "${BASH_SOURCE[0]%/*}/lib/tmux-common.sh"

SELF="${BASH_SOURCE[0]}"
STEPS=${CLAUDE_STEPS_BIN:-claude-steps}
WIDE=120 # the popup's columns below which the layout stacks
TALL=34  # the popup's rows below which it stacks: the side column holds the status and the list

die() { printf '\n  %s\n' "$*" >&2; sleep 1.8; exit 1; }

valid_pane() { case "${1:-}" in %[0-9]*) return 0 ;; esac; return 1; }

open_popup() {
    local pane="$1"
    # Status 0 after msg: run-shell would replace the message with "returned 1".
    valid_pane "$pane" && pane_exists "$pane" || { msg "steps: no such pane"; return 0; }
    command -v "$STEPS" >/dev/null 2>&1 || { msg "steps: claude-steps is not installed (make install in ~/dev/claude-steps)"; return 0; }
    popup "${2:-}" -E -w 92% -h 88% -T ' claude steps ' "exec bash '$SELF' pick '$pane' '${2:-}'"
}

# The list's rows: each session's pane, when its transcript last had a
# message, and its title, cut to the side column. With no width the binary
# cuts nothing, and fzf cuts a row at its right end.
board() {
    CLICOLOR_FORCE=1 COLUMNS=${STEPS_SIDE:-0} "$STEPS" board --ids --brief
}

# The rows the status may take: the column less the 8 rows it spends on
# frames, the prompt and the footer, and room for up to six sessions. 0
# outside fzf, where there is no column.
status_room() {
    local count=${FZF_TOTAL_COUNT:-0}
    if [ -z "${FZF_LINES:-}" ]; then echo 0; return; fi
    echo $(( FZF_LINES - 8 - (count < 6 ? count : 6) ))
}

# One session's status for the side column: what it is and where, each
# label's latest event, the rounds with no collect seen, and the notes. A
# status taller than its room is cut and says so, and the main panel holds it
# whole under the steps (`preview`), so it never takes the list's rows. The
# box keeps the height of the tallest status it has shown (STEPS_TALL holds
# it), so the list under it stays put as the cursor moves. fzf drops a
# header's trailing empty lines, so the padding is lines of one space.
status() {
    local out n tall=0 most
    out=$(CLICOLOR_FORCE=1 COLUMNS=${STEPS_SIDE:-0} "$STEPS" show --head "$1" 2>&1)
    n=$(( $(printf '%s\n' "$out" | wc -l) ))
    most=$(status_room)
    if [ "$most" -gt 1 ] && [ "$n" -gt "$most" ]; then
        printf '%s\n' "$out" | head -n $(( most - 1 ))
        printf '… %s more lines under the steps\n' $(( n - most + 1 ))
        n=$most
    else
        printf '%s\n' "$out"
    fi
    [ -n "${STEPS_TALL:-}" ] || return 0
    tall=$(( $(cat "$STEPS_TALL" 2>/dev/null || echo 0) ))
    tall=$(( n > tall ? n : tall ))
    [ "$most" -le 1 ] || tall=$(( tall > most ? most : tall ))
    printf '%s\n' "$tall" >"$STEPS_TALL"
    for (( ; n < tall; n++ )); do printf ' \n'; done
}

# One session for the main panel: its steps, or with the panel labelled
# "history" its whole timeline. The label is the toggle's state. Stacked,
# the panel is the whole session view, the status on top: it is what the
# popup is opened to read, and `pick` sizes the panel to hold it whole. In
# the side layout the steps are on top, and the status follows them when
# `status` had to cut it.
preview() {
    local all='' most n
    case "${FZF_PREVIEW_LABEL:-}" in *history*) all=--all ;; esac
    if [ "${STEPS_LAYOUT:-}" = stacked ]; then
        CLICOLOR_FORCE=1 COLUMNS=${FZF_PREVIEW_COLUMNS:-0} "$STEPS" show ${all:+"$all"} "$1" 2>&1
        return
    fi
    CLICOLOR_FORCE=1 COLUMNS=${FZF_PREVIEW_COLUMNS:-0} "$STEPS" show --no-head ${all:+"$all"} "$1" 2>&1
    most=$(status_room)
    n=$(( $(COLUMNS=${STEPS_SIDE:-0} "$STEPS" show --head "$1" 2>&1 | wc -l) ))
    [ "$most" -gt 1 ] && [ "$n" -gt "$most" ] || return 0
    echo
    CLICOLOR_FORCE=1 COLUMNS=${FZF_PREVIEW_COLUMNS:-0} "$STEPS" show --head "$1" 2>&1
}

# What a finished load does. The first places the cursor on the pane the key
# was pressed in; a later one, after a note, leaves the cursor where it is (a
# note must not throw it back to the origin) and redraws the main panel and
# the status for the row as it now reads, since the pane may run another
# session by then. The note's own key cannot: fzf expands its {2} before the
# reload, and a reload that keeps the cursor fires no focus. No key pressed
# yet means the first load.
loaded() {
    if [ -z "${FZF_KEY:-}" ]; then
        printf 'pos(%s)' "$1"
    elif [ "${STEPS_LAYOUT:-}" = side ]; then
        printf "refresh-preview+transform-header(bash '%s' status {2})" "$SELF"
    else
        printf 'refresh-preview'
    fi
}

# The panel's label names what it shows and its order, and stacked it shows
# the status above the steps.
toggle() {
    local lead=''
    [ "${STEPS_LAYOUT:-}" = stacked ] && lead='status · '
    case "${FZF_PREVIEW_LABEL:-}" in
        *history*) printf 'change-preview-label( %ssteps · newest first )+refresh-preview' "$lead" ;;
        *) printf 'change-preview-label( %shistory · newest first )+refresh-preview' "$lead" ;;
    esac
}

pick() {
    local origin="$1" client="${2:-}" rows err tall pos out st pane session c size lines cols side window label
    local count head list room most
    local -a layout
    command -v "$STEPS" >/dev/null 2>&1 || die "claude-steps is not installed"

    # The side column takes about a third of the popup, within bounds, and the
    # main panel the rest. Given the preview's size, fzf draws the column four
    # columns narrower than what is left (the preview's borders), and a row or
    # a status line six narrower than the column (its borders and gutter).
    size=$(stty size </dev/tty 2>/dev/null)
    lines=${size%% *} cols=${size##* }
    lines=${lines:-0} cols=${cols:-0}
    label=' steps · newest first '
    if [ "$cols" -ge "$WIDE" ] && [ "$lines" -ge "$TALL" ]; then
        side=$(( cols * 36 / 100 ))
        side=$(( side < 50 ? 50 : side > 72 ? 72 : side ))
        export STEPS_LAYOUT=side STEPS_SIDE=$(( side - 6 ))
        window="right,$(( cols - side - 4 )),wrap,border-rounded"
        # The status follows the cursor; after a note, `loaded` redraws it.
        layout=(--header-border=rounded --header-label=' status '
                --bind="focus:transform-header(bash '$SELF' status {2})"
                --footer=$'enter switch · tab history · ctrl-n note\nctrl-d/u scroll · esc close')
    else
        export STEPS_LAYOUT=stacked STEPS_SIDE=$(( cols > 6 ? cols - 6 : 0 ))
        label=' status · steps · newest first '
        layout=(--footer='enter switch · tab history · ctrl-n note · ctrl-d/u scroll · esc close')
    fi

    err=$(mktemp "${TMPDIR:-/tmp}/tmux-steps.XXXXXX") || die "cannot make a temporary file"
    tall=$(mktemp "${TMPDIR:-/tmp}/tmux-steps.XXXXXX") || { rm -f "$err"; die "cannot make a temporary file"; }
    # shellcheck disable=SC2064  # expand now: err and tall are local
    trap "rm -f '$err' '$tall'" EXIT
    export STEPS_TALL="$tall"
    rows=$(board 2>"$err") || die "$(cat "$err")"
    [ -n "$rows" ] || die "no tmux pane runs a Claude session"

    # Start on the pane the key was pressed in.
    pos=$(printf '%s\n' "$rows" | awk -F'\t' -v p="$origin" '$1 == p { print NR; exit }')

    # Stacked, the panel takes the rows the list does not need: its frame,
    # the prompt and the footer (6), and up to six sessions. It takes more
    # when the status it opens on would not fit whole, while the list keeps
    # three rows. That status is the row the cursor starts on, the first when
    # the origin pane runs no Claude session, measured as the panel draws it:
    # painted, since a glyph can fold a line, and four columns narrower than
    # the popup. fzf draws the panel's frame outside the size it is given.
    if [ "$STEPS_LAYOUT" = stacked ]; then
        count=$(printf '%s\n' "$rows" | wc -l)
        list=$(( (count < 6 ? count : 6) + 6 ))
        session=$(printf '%s\n' "$rows" | awk -F'\t' -v n="${pos:-1}" 'NR == n { print $2; exit }')
        head=$(( $(CLICOLOR_FORCE=1 COLUMNS=$(( cols > 4 ? cols - 4 : 0 )) "$STEPS" show --head "$session" 2>/dev/null | wc -l) ))
        room=$(( lines - list - 2 ))
        most=$(( lines - (count < 3 ? count : 3) - 8 ))
        [ "$room" -ge "$head" ] || room=$(( head < most ? head : most ))
        window="up,$(( room > 3 ? room : 3 )),wrap,border-rounded"
    fi

    # The main panel opens at its top, where the newest steps are: it does not
    # follow its output down.
    out=$(printf '%s\n' "$rows" | fzf \
            --ansi --delimiter='\t' --with-nth=3 \
            --no-multi --no-sort --no-mouse --layout=reverse --header-first --info=inline-right \
            --prompt='session > ' \
            --list-border=rounded --list-label=' sessions ' \
            --preview="bash '$SELF' preview {2}" \
            --preview-window="$window" --preview-label="$label" \
            --bind='ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
            --bind="tab:transform(bash '$SELF' toggle)" \
            --bind="load:transform(bash '$SELF' loaded ${pos:-1})" \
            --bind="ctrl-n:execute(bash '$SELF' note {2})+reload(bash '$SELF' board 2>/dev/null)" \
            "${layout[@]}" \
            --color="$(fzf_colors_from_palette)" --color='header:-1')
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
    status) status "${2:-}" ;;
    preview) preview "${2:-}" ;;
    loaded) loaded "${2:-}" ;;
    toggle) toggle ;;
    note) note "${2:-}" ;;
    *) printf 'usage: %s {open <pane> [client]|pick <pane> [client]|board|status <session>|preview <session>|loaded <position>|toggle|note <session>}\n' "${0##*/}" >&2; exit 64 ;;
esac
