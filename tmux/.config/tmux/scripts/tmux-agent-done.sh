#!/usr/bin/env bash
# Transitional forwarder to `tmux-agent-status.sh done` (2026-09-28). Claude
# sessions started earlier still run this path from their Stop/Notification
# hooks. Delete it once none predate that change.
exec bash "$(dirname "${BASH_SOURCE[0]}")/tmux-agent-status.sh" done "$@"
