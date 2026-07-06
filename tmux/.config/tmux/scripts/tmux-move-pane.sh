#!/usr/bin/env bash
# tmux-move-pane.sh — interactively move the current pane into another window.
#
# The source pane id is stashed in the tmux global env var MOVE_SRC_PANE by the
# key binding (via `run-shell`, which expands #{pane_id}). We can't pass it as a
# script argument because `display-popup` does NOT expand formats in its command
# argument — it would arrive as the literal string "#{pane_id}".
#
# Flow: read source pane -> pick a target window (fzf, with live preview)
#       -> pick a position -> join-pane -> follow the pane to its new home.
set -uo pipefail

# Show a message inside the popup long enough to read, then bail.
die() { printf '\n  %s\n' "$*" >&2; sleep 1.8; exit 1; }

# --- resolve the source pane (stashed by the key binding, then consumed) ---
SRC=$(tmux show-environment -g MOVE_SRC_PANE 2>/dev/null | cut -d= -f2-)
tmux set-environment -gu MOVE_SRC_PANE 2>/dev/null || true
case "$SRC" in
  %[0-9]*) : ;;
  *) die "couldn't determine the source pane (got: '${SRC}')" ;;
esac

SESSION=$(tmux display-message -t "$SRC" -p '#{session_name}')
SRC_WIN=$(tmux display-message -t "$SRC" -p '#{window_index}')
export SESSION

# 1. Pick the destination window (exclude the source pane's own window).
menu=$(tmux list-windows -t "$SESSION" \
         -F '#{window_index}: #{window_name}  [#{window_panes} panes]' \
       | awk -v cur="$SRC_WIN" '{ idx=$1; sub(/:.*/,"",idx); if (idx != cur) print }')

if [ -z "$menu" ]; then
  echo "No other window in session '$SESSION' to move into."
  sleep 1.6; exit 0
fi

pick=$(printf '%s\n' "$menu" | fzf \
         --prompt='move pane → window > ' \
         --header='pick a window   (Esc to cancel)' \
         --height=100% --reverse --border=none \
         --preview='tmux capture-pane -pe -t "$SESSION:$(printf "%s" {} | cut -d: -f1 | tr -d " ")" 2>/dev/null' \
         --preview-window=right,60%) || exit 0
[ -z "$pick" ] && exit 0
DST_WIN=$(printf '%s' "$pick" | cut -d: -f1 | tr -d ' ')

# 2. Pick the position. Unique first letters: r/l/t/b — type one, Enter.
pos=$(printf 'right\nleft\ntop\nbottom\n' | fzf \
        --prompt='position > ' \
        --header='where in that window?   (type r/l/t/b)' \
        --height=100% --reverse --border=none) || exit 0
[ -z "$pos" ] && exit 0

# tmux split convention: -h = left/right split, -v = top/bottom; -b = before.
case "$pos" in
  right)  flags='-h'    ;;
  left)   flags='-h -b' ;;
  top)    flags='-v -b' ;;
  bottom) flags='-v'    ;;
  *) exit 0 ;;
esac

# 3. Move it. join-pane targets the active pane of the destination window.
# Only follow the pane if the move actually succeeded (don't switch on failure).
# shellcheck disable=SC2086
if err=$(tmux join-pane $flags -s "$SRC" -t "$SESSION:$DST_WIN" 2>&1); then
  tmux select-window -t "$SESSION:$DST_WIN"   # follow; comment out to stay put
else
  die "join-pane failed: ${err:-unknown error}"
fi
