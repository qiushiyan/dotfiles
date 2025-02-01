#!/bin/bash
SESSION_NAME="ghostty"

TMUX_PATH=/opt/homebrew/bin/tmux

# Check if the session already exists
$TMUX_PATH has-session -t $SESSION_NAME 2>/dev/null

if [ $? -eq 0 ]; then
  # If the session exists, reattach to it
  $TMUX_PATH attach-session -t $SESSION_NAME
else
  # If the session doesn't exist, start a new one
  $TMUX_PATH new-session -s $SESSION_NAME -d
  $TMUX_PATH attach-session -t $SESSION_NAME
fi

cd ~/workspace || exit
