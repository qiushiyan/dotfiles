# tmux scripting patterns

Patterns for scripting tmux panes programmatically, e.g. Claude Code driving Codex in another pane, and the traps any tmux script or `tmux.conf` edit can hit.

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

Instead of fixed `sleep` calls, poll for a specific prompt or text pattern using `tmux-wait-for-text` (defined in `zsh/.config/zsh/tmux-utils.zsh`, loaded in every shell):

```bash
# wait up to 15s for codex's › prompt to appear
tmux-wait-for-text -t work:1.2 -p '›' -T 15

# wait for a specific string (fixed match, not regex)
tmux-wait-for-text -t work:1.2 -p 'done' -F -T 30
```

The pattern is an extended regex unless `-F`; `tmux-wait-for-text -h` lists the
flags. It exits 0 on a match and 1 on timeout.

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
tmux-wait-for-text -t work:1.2 -p '›' -T 10

tmux send-keys -t work:1.2 -l -- "your prompt"
sleep 0.5
tmux send-keys -t work:1.2 Enter
```

## End-to-end example: ask codex a question and read the response

```bash
PANE="work:1.2"
QUESTION="What does this function do?"

# wait for codex to be ready
tmux-wait-for-text -t $PANE -p '›' -T 10

# send question
tmux send-keys -t $PANE -l -- "$QUESTION"
sleep 0.5
tmux send-keys -t $PANE Enter

# wait for response (poll for next prompt)
tmux-wait-for-text -t $PANE -p '›' -T 30

# read response (skip the question line)
tmux capture-pane -t $PANE -p -J | sed -n "/$QUESTION/,\$p" | sed '1d'
```

## Traps

- **A missing target is not an error.** tmux 3.7c answers
  `display-message -p -t <gone pane or window>` with exit status 0 and empty
  output, so an existence check tests the output, as `pane_exists`/`win_exists`
  in `scripts/lib/tmux-common.sh` do.
- **`=name` is for session targets only.** `has-session`, `kill-session` and
  `attach-session` take the exact-match form. `show-option` takes a pane
  target, where `-t "=name"` resolves to nothing and the option reads back
  empty, with exit status 0.
- **`IFS= read -r a b c` does not split.** The whole line lands in `a`; use
  `IFS=' '` to split on spaces.
- **`display-popup` does not expand formats in its command.** It expands them
  in options such as `-d`, so `#{session_name}` in the command arrives as
  literal text. Bind through `run-shell`, which expands its command, and pass
  values as arguments, or detect them inside the popup.
- **A later `unbind` silently kills an earlier `bind`.** `tmux.conf` is one
  pass, so an `unbind` below a binding for the same key removes it with no error.
- **`message-style` needs `fill=` on 3.7.** Without it the message bar paints
  only behind its text.
