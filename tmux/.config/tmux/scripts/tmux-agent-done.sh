#!/usr/bin/env bash
# tmux-agent-done.sh — flag the current tmux window as "agent finished / wants you".
#
# Called by a coding-agent's completion hook (Claude Code Stop/Notification,
# Codex notify, …). It relies on $TMUX_PANE — which tmux sets for every pane and
# the agent's child processes inherit — to find which window to flag. The window
# gets @agent_done=1 (→ a dot on its status chip) and tmux-agent-recount.sh
# refreshes the "◷ N" corner badge. Visiting the window clears the dot — the
# nav keybindings do that inline (see tmux.conf), since only the client knows
# which window you landed on.
#
# No-ops cleanly when not inside tmux, so it's safe as a global agent hook.
# Always exits 0 — a non-zero Stop hook would block the agent from stopping.

set -u

[ -z "${TMUX_PANE:-}" ] && exit 0   # not running inside tmux

pane="$TMUX_PANE"
win="$(tmux display-message -p -t "$pane" '#{window_id}' 2>/dev/null)" || exit 0
[ -z "$win" ] && exit 0

# don't flag a window you're already looking at (active window of an attached
# session) — you can see the agent finish; the dot would just get stuck.
visible="$(tmux display-message -p -t "$pane" '#{&&:#{window_active},#{session_attached}}' 2>/dev/null)"
[ "$visible" = "1" ] && exit 0

tmux set-option -w -t "$win" @agent_done 1 2>/dev/null
bash "$HOME/.config/tmux/scripts/tmux-agent-recount.sh"   # refresh the ◷ badge

exit 0
