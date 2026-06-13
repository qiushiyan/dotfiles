#!/usr/bin/env bash
# tmux-agent-recount.sh — recompute the "agents ready" badge counts.
#
# Window-agnostic on purpose: it does NOT care which window is current. It just
# counts, per session, the windows whose @agent_done flag is set, and stores the
# total in that session's @agents_ready option (which drives the "◷ N" badge in
# status-right). Because it needs no "current window" context, it runs correctly
# from anywhere — a keybinding, an agent hook, a background run-shell.
#
# The actual flag *clearing* is done inline by whatever knows the right window
# (the nav keybindings, in client context; the worktree popup, by name). This
# script only keeps the counter honest. Always exits 0.

set -u

tmux list-sessions -F '#{session_name}' 2>/dev/null | while IFS= read -r s; do
  n="$(tmux list-windows -t "$s" -F '#{@agent_done}' 2>/dev/null | grep -c '^1$')"
  tmux set-option -t "$s" @agents_ready "$n" 2>/dev/null
done
tmux refresh-client -S 2>/dev/null

exit 0
