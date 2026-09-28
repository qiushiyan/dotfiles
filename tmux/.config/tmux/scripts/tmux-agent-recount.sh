#!/usr/bin/env bash
# Transitional forwarder to `tmux-agent-status.sh recount` (2026-09-28), for
# callers loaded before that change. Delete it once none remain.
exec bash "$(dirname "${BASH_SOURCE[0]}")/tmux-agent-status.sh" recount "$@"
