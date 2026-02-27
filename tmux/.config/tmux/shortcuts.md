# tmux shortcuts

Prefix: `C-a` (or `C-b`)

## Sessions

| Key | Action |
|-----|--------|
| `prefix T` | sesh fuzzy session picker |
| `prefix C-c` | new session |
| `prefix $` | rename current session |
| `prefix d` | detach |
| `prefix Q` | kill all other sessions |

```bash
tmux ls                        # list sessions
tmux attach -t <name|number>   # attach to session
tmux rename-session -t 1 work  # rename session
tmux kill-session -a           # kill all except current
```

## Windows (tabs)

| Key | Action |
|-----|--------|
| `prefix c` | new window |
| `prefix N` | new window (after current) |
| `prefix m` | rename window |
| `prefix x` | kill pane/window |
| `prefix C-h / C-l` | prev / next window |
| `prefix Tab` | last window |
| `Shift-Left / Right` | swap window position |

## Panes (splits)

| Key | Action |
|-----|--------|
| `prefix \|` | split horizontal (side by side) |
| `prefix -` | split vertical (stacked) |
| `prefix h / j / k / l` | navigate panes |
| `prefix H / J / K / L` | resize panes |
| `prefix z` | zoom/unzoom (fullscreen toggle) |
| `prefix x` | kill pane |
| `prefix !` | break pane to hidden |
| `prefix @` | join hidden pane back |

## Resurrect (save/restore across reboots)

| Key | Action |
|-----|--------|
| `prefix C-s` | save session layout |
| `prefix C-r` | restore session layout |

## Other

| Key | Action |
|-----|--------|
| `prefix r` | reload config |
| `prefix C-k` | clear screen + scrollback |
