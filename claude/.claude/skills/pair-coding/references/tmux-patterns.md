# tmux scripting patterns

## Target format

`session:window.pane` (e.g. `work:1.2`).

## Control keys

```bash
tmux send-keys -t $PANE C-c      # interrupt
tmux send-keys -t $PANE C-d      # EOF / exit
tmux send-keys -t $PANE Escape   # escape
```

## Wait for prompt

Use `tmux-wait-for-text` instead of fixed sleeps:

```bash
tmux-wait-for-text -t $PANE -p '›' -T 15
```

Options: `-p` pattern (regex), `-F` fixed string, `-T` timeout seconds, `-i` poll interval, `-l` history lines. Defined in `zsh/.config/zsh/tmux-utils.zsh`, loaded in every shell.

## Read pane output

```bash
# full visible content (joined lines)
tmux capture-pane -t $PANE -p -J

# last N lines of scrollback
tmux capture-pane -t $PANE -p -J -S -200

# response after a known input (token-efficient) — anchor on a short,
# distinctive fragment, since long/multiline input may wrap in the pane
tmux capture-pane -t $PANE -p -J | sed -n '/known input/,$p' | sed '1d'
```

## Query state

```bash
tmux display-message -p '#S'       # session name
tmux display-message -p '#I'       # window index
tmux display-message -p '#P'       # pane index
tmux list-panes                    # panes in current window
```
