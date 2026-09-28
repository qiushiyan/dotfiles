#!/usr/bin/env bash
# Transitional forwarder to tmux-agent-status.sh, which replaced this script on
# 2026-09-28. Shells and Claude sessions started before then still call this
# path (zsh prompt hooks, SessionStart/SessionEnd hooks). Delete it once none
# predate that change.
set -u
owner="$(dirname "${BASH_SOURCE[0]}")/tmux-agent-status.sh"
case "${1:-}" in
    clear-session)    shift; exec bash "$owner" clear claude "$@" ;;
    activate-session) shift; exec bash "$owner" activate claude "$@" ;;
    clear)            shift; exec bash "$owner" clear claude "$@" ;;
    reconcile)        shift; exec bash "$owner" reconcile "$@" ;;
esac
exit 0
