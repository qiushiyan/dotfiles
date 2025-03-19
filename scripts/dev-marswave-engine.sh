#!/bin/bash
SESSION="preprocessing-engine"
PROJECT="$HOME/workspace/marswave"
TMUX=/opt/homebrew/bin/tmux

if $TMUX has-session -t $SESSION 2>/dev/null; then
  $TMUX attach-session -t $SESSION
else
  $TMUX new-session -s $SESSION -c "$PROJECT/preprocessing-engine" -n 'engine' -d

  $TMUX new-window -t $SESSION:2 -n 'deepsearch' -c "$PROJECT/preprocessing-engine/deepsearch" "n ."

  # Create the third window 'misc'
  $TMUX new-window -t $SESSION:3 -n 'misc' -c "$PROJECT"

  # Select the first window
  $TMUX select-window -t $SESSION:1

  # Send keys to the first window
  $TMUX send-keys -t $SESSION:1 "n ." C-m

  # Attach to the session
  $TMUX attach-session -t $SESSION
fi
