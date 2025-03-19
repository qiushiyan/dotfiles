#!/bin/bash
SESSION="manager"
PROJECT="$HOME/workspace/marswave"
TMUX=/opt/homebrew/bin/tmux

if $TMUX has-session -t $SESSION 2>/dev/null; then
  $TMUX attach-session -t $SESSION
else
  $TMUX new-session -s $SESSION -c "$PROJECT/manager-fe" -n 'manager-web' -d

  $TMUX new-window -t $SESSION:2 -n 'manager-server' -c "$PROJECT/manager-server" -d
  $TMUX split-window -h -t $SESSION:2 -c "$PROJECT/manager-server" "pnpm dev"

  $TMUX new-window -t $SESSION:3 -n 'misc' -c "$PROJECT"
  $TMUX rename-window -t $SESSION:3 'misc'

  $TMUX select-window -t $SESSION:1
  $TMUX send-keys -t $SESSION:1 "n ." C-m
  $TMUX attach-session -t $SESSION
fi
