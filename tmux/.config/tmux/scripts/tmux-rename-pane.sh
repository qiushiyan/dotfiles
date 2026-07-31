#!/usr/bin/env bash
# tmux-rename-pane.sh — label the current pane, from a popup text prompt.
#
# Bound to `prefix M`. The target pane id is stashed in the tmux global env var
# RENAME_PANE_TARGET by the key binding (via `run-shell`, which expands formats);
# we can't take it as a script argument because `display-popup` does NOT expand
# #{...} in its command argument. Same idiom as tmux-move-pane.sh.
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

die() { printf '\n  %s\n' "$*" >&2; sleep 1.8; exit 1; }

# --- resolve the target pane (stashed by the key binding, then consumed) ---
PANE=$(tmux show-environment -g RENAME_PANE_TARGET 2>/dev/null | cut -d= -f2-)
tmux set-environment -gu RENAME_PANE_TARGET 2>/dev/null || true
case "$PANE" in
  %[0-9]*) : ;;
  *) die "couldn't determine the pane (got: '${PANE}')" ;;
esac

# Prefill with the label only if it's YOURS. Naming a pane sets allow-set-title off on
# it (see tmux.conf), so that option doubles as a reliable "is this label mine?" flag —
# without it we'd prefill the hostname, or whatever status the program inside last
# painted over the title.
current=$(tmux display-message -p -t "$PANE" '#{?allow-set-title,,#{pane_title}}')

# --print-query is the whole point: it echoes the typed line. Exit 130 is Esc/^C;
# with no list to match against, Enter exits 1 and still prints the query.
label=$(: | fzf \
          --print-query --disabled --no-mouse --no-info --no-separator \
          --prompt='pane title > ' \
          --header='Enter apply · empty clears · Esc cancel' \
          --query="$current" \
          --height=100% --reverse --border=none)
st=$?
[ "$st" = 130 ] && exit 0

label=$(printf '%s' "$label" | sed -n 1p)

# trim surrounding whitespace; a blank label means "reset"
label="${label#"${label%%[![:space:]]*}"}"
label="${label%"${label##*[![:space:]]}"}"

if [ -z "$label" ]; then
  tmux select-pane -t "$PANE" -T ""
  tmux set-option -p -u -t "$PANE" allow-set-title
  # border OFF is owned by the reconciler: it keeps the row when another pane
  # in the window is still named or shows a Claude context chip (see tmux.conf)
  bash "$HOME/.config/tmux/scripts/tmux-claude-ctx.sh" reconcile "$PANE"
else
  tmux set-option -w -t "$PANE" pane-border-status top
  tmux set-option -p -t "$PANE" allow-set-title off
  tmux select-pane -t "$PANE" -T "$label"
fi
