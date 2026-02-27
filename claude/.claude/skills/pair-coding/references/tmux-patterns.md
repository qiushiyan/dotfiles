# tmux scripting patterns

## Target format

`session:window.pane` (e.g. `work:1.2`).

## Send input

Always send text and Enter separately for TUI apps. Use `-l` for literal text:

```bash
tmux send-keys -t $PANE -l -- "your message"
sleep 0.5
tmux send-keys -t $PANE Enter
```

## Control keys

```bash
tmux send-keys -t $PANE C-c      # interrupt
tmux send-keys -t $PANE C-d      # EOF / exit
tmux send-keys -t $PANE Escape   # escape
```

## Wait for prompt

Use `wait-for-text.sh` instead of fixed sleeps:

```bash
scripts/wait-for-text.sh -t $PANE -p '›' -T 15
```

Options: `-p` pattern (regex), `-F` fixed string, `-T` timeout seconds, `-i` poll interval, `-l` history lines.

## Read pane output

```bash
# full visible content (joined lines)
tmux capture-pane -t $PANE -p -J

# last N lines of scrollback
tmux capture-pane -t $PANE -p -J -S -200

# response after a known input (token-efficient)
tmux capture-pane -t $PANE -p -J | sed -n '/known input/,$p' | sed '1d'
```

## Query state

```bash
tmux display-message -p '#S'       # session name
tmux display-message -p '#I'       # window index
tmux display-message -p '#P'       # pane index
tmux list-panes                    # panes in current window
```
