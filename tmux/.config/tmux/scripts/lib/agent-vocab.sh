# shellcheck shell=bash disable=SC2034  # every name here is read by a sourcer
# lib/agent-vocab.sh — the per-pane agent-status vocabulary, defined once.
#
# The pane user options below are the boundary between the agents that
# publish status and tmux, which draws it (tmux.conf, pane-border-format).
# tmux-agent-status.sh owns every verb that writes or clears them; the other
# readers take the names from here:
#
#   tmux-agent-status.sh        the owner (clear/activate/sweep/reconcile/done)
#   statusline-chip.sh          sources the owner and calls its publish builder
#   zsh tmux-utils.zsh          the prompt sweep's presence test
#
# Both bash and zsh source this file, so it holds plain scalar assignments
# only. Lists are space-separated strings, never arrays: the two shells index
# arrays differently and zsh does not word-split unquoted expansions.

# The owner of every verb over these options.
AGENT_STATUS_BIN="$HOME/.config/tmux/scripts/tmux-agent-status.sh"

# Claude context chip. A value in the PRESENCE option is what "chip shown"
# means. The statusline publishes FIELDS on every accepted render, in this
# order, which is also the argument order of agent_claude_publish. OWNER
# records the publishing session; TOMBSTONE is the activation barrier that
# refuses a torn-down session's orphan renders (context-chip.md, Lifecycle).
AGENT_CLAUDE_PRESENCE=@claude_ctx
AGENT_CLAUDE_OWNER=@claude_ctx_sid
AGENT_CLAUDE_TOMBSTONE=@claude_ctx_dead
AGENT_CLAUDE_FIELDS="@claude_ctx @claude_ctx_sid @claude_ctx_model @claude_ctx_effort @claude_ctx_account @claude_ctx_5h @claude_ctx_7d @claude_ctx_wk @claude_ctx_wk_model"

# Codex. The zsh wrapper activates it for exactly the TUI's lifetime; Codex
# itself writes its runtime state into pane_title. PRESENCE is 1 while it runs;
# PATH is the compact workspace path the border leads with.
AGENT_CODEX_PRESENCE=@codex_active
AGENT_CODEX_PATH=@codex_path
AGENT_CODEX_FIELDS="@codex_active @codex_path"

# The agents the prompt sweep knows how to retire, in sweep order.
AGENT_KINDS="claude codex"
