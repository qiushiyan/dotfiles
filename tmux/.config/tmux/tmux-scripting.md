# tmux scripting patterns

Patterns for scripting tmux panes programmatically, e.g. Claude Code driving Codex in another pane.

## Query current state

```bash
tmux display-message -p '#S'                          # session name
tmux display-message -p 'session:#S window:#I pane:#P' # full context
tmux list-sessions                                     # all sessions
tmux list-windows                                      # windows in current session
tmux list-panes                                        # panes in current window
```

## Send input to another pane

Always send text and Enter as separate commands — TUI apps (codex, fzf, etc.) may not process them correctly in a single call.

Use `-l` (literal) to avoid shell interpretation of special characters (`$`, `!`, etc.):

```bash
# send text, wait briefly, then submit
tmux send-keys -t work:1.2 -l -- "your message here"
sleep 0.5
tmux send-keys -t work:1.2 Enter
```

Target format: `session:window.pane` (e.g. `work:1.2`).

### Control keys

```bash
tmux send-keys -t work:1.2 C-c      # interrupt (Ctrl+C)
tmux send-keys -t work:1.2 C-d      # EOF / exit (Ctrl+D)
tmux send-keys -t work:1.2 Escape   # escape key
```

## Wait for output (synchronization)

Instead of fixed `sleep` calls, poll for a specific prompt or text pattern using `wait-for-text.sh`:

```bash
# wait up to 15s for codex's › prompt to appear
./tmux/.skills/scripts/wait-for-text.sh -t work:1.2 -p '›' -T 15

# wait for a specific string (fixed match, not regex)
./tmux/.skills/scripts/wait-for-text.sh -t work:1.2 -p 'done' -F -T 30
```

Options:
- `-t` target pane (required)
- `-p` pattern to match (required, regex by default)
- `-F` treat pattern as fixed string
- `-T` timeout in seconds (default: 15)
- `-i` poll interval in seconds (default: 0.5)
- `-l` history lines to search (default: 1000)

Exits 0 on match, 1 on timeout. On timeout, prints last captured text to stderr.

## Read pane output

Use `-J` to join wrapped lines (prevents long lines from splitting into multiple lines in output).

### Full pane content (visible area)

```bash
tmux capture-pane -t work:1.2 -p -J
```

### Recent scrollback (last N lines)

```bash
tmux capture-pane -t work:1.2 -p -J -S -200
```

### Full scrollback history

```bash
tmux capture-pane -t work:1.2 -p -J -S -
```

### Response after a known input (token-efficient)

Since the sender already knows what it sent, use the input as an anchor:

```bash
tmux capture-pane -t work:1.2 -p -J | sed -n '/your message here/,$p' | sed '1d'
```

## Launch a CLI tool in another pane

```bash
tmux send-keys -t work:1.2 "codex" Enter

# wait for codex prompt instead of fixed sleep
./tmux/.skills/scripts/wait-for-text.sh -t work:1.2 -p '›' -T 10

tmux send-keys -t work:1.2 -l -- "your prompt"
sleep 0.5
tmux send-keys -t work:1.2 Enter
```

## End-to-end example: ask codex a question and read the response

```bash
PANE="work:1.2"
QUESTION="What does this function do?"
WAIT="./tmux/.skills/scripts/wait-for-text.sh"

# wait for codex to be ready
$WAIT -t $PANE -p '›' -T 10

# send question
tmux send-keys -t $PANE -l -- "$QUESTION"
sleep 0.5
tmux send-keys -t $PANE Enter

# wait for response (poll for next prompt)
$WAIT -t $PANE -p '›' -T 30

# read response (skip the question line)
tmux capture-pane -t $PANE -p -J | sed -n "/$QUESTION/,\$p" | sed '1d'
```
