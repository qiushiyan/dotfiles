#!/bin/bash
SESSION="itell"
PROJECT="$HOME/workspace/aloe/itell/apps/demo"
TMUX=/opt/homebrew/bin/tmux

if $TMUX has-session -t $SESSION 2>/dev/null; then
  # If the session exists, reattach to it
  $TMUX attach-session -t $SESSION
else
  # Create new session with neovim in specified directory
  $TMUX new-session -s $SESSION -c "$PROJECT" -d
  # Other windows
  $TMUX new-window -t $SESSION:2 -n 'servers' -c "$PROJECT" -d
  $TMUX send-keys -t $SESSION:2 'pnpm dev' C-m
  $TMUX rename-window -t $SESSION:2 'servers'
  $TMUX new-window -t $SESSION:3 -n 'misc' -c "$HOME/workspace"
  $TMUX rename-window -t $SESSION:3 'misc'

  # Ensure we're on the first window
  $TMUX select-window -t $SESSION:1
  # Attach to session
  $TMUX attach-session -t $SESSION
fi
