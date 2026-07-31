# ~/.config/zsh/tmux-utils.zsh
# tmux helper functions for scripting panes (used by pair-coding skill)

# --------------------------------------------------------------------
# codex-pane-setup - Find or create a sibling pane and start Codex
# Prints the target pane ID (e.g. work:1.2) on success
# --------------------------------------------------------------------
codex-pane-setup() {
  if [[ -z "$TMUX" ]]; then
    echo "ERROR: not inside tmux" >&2
    return 1
  fi

  # Use TMUX_PANE (per-pane env var) to reliably identify the calling pane,
  # NOT display-message which returns the client's focused pane (wrong when
  # the user is viewing a different window).
  local session=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}')
  local window=$(tmux display-message -t "$TMUX_PANE" -p '#{window_index}')
  local current_pane=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_index}')
  local pane_count=$(tmux list-panes -t "$session:$window" | wc -l | tr -d ' ')

  if [[ "$pane_count" -eq 1 ]]; then
    tmux split-window -h -t "$session:$window.$current_pane" -c "#{pane_current_path}"
    tmux select-pane -t "$session:$window.$current_pane"
  fi

  local target_pane=$(tmux list-panes -t "$session:$window" -F '#{pane_index}' | grep -v "^${current_pane}$" | head -1)

  if [[ -z "$target_pane" ]]; then
    echo "ERROR: could not find sibling pane" >&2
    return 1
  fi

  local target="$session:$window.$target_pane"
  local pane_cmd=$(tmux display-message -t "$target" -p '#{pane_current_command}')

  if [[ "$pane_cmd" != *"codex"* ]]; then
    tmux send-keys -t "$target" "codex" Enter
  fi

  echo "$target"
}

# --------------------------------------------------------------------
# tmux-wait-for-text - Poll a tmux pane until a pattern appears
# Usage: tmux-wait-for-text -t <target> -p <pattern> [-F] [-T timeout] [-i interval] [-l lines]
# --------------------------------------------------------------------
tmux-wait-for-text() {
  local target="" pattern="" grep_flag="-E" timeout=15 interval=0.5 lines=1000

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--target)   target="$2"; shift 2 ;;
      -p|--pattern)  pattern="$2"; shift 2 ;;
      -F|--fixed)    grep_flag="-F"; shift ;;
      -T|--timeout)  timeout="$2"; shift 2 ;;
      -i|--interval) interval="$2"; shift 2 ;;
      -l|--lines)    lines="$2"; shift 2 ;;
      -h|--help)
        echo "Usage: tmux-wait-for-text -t <target> -p <pattern> [-F] [-T sec] [-i sec] [-l lines]"
        return 0 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done

  if [[ -z "$target" || -z "$pattern" ]]; then
    echo "ERROR: -t <target> and -p <pattern> are required" >&2
    return 1
  fi

  local start_epoch=$(date +%s)
  local deadline=$((start_epoch + timeout))
  local pane_text

  while true; do
    pane_text="$(tmux capture-pane -p -J -t "$target" -S "-${lines}" 2>/dev/null || true)"

    if printf '%s\n' "$pane_text" | grep $grep_flag -- "$pattern" >/dev/null 2>&1; then
      return 0
    fi

    local now=$(date +%s)
    if (( now >= deadline )); then
      echo "Timed out after ${timeout}s waiting for: $pattern" >&2
      return 1
    fi

    sleep "$interval"
  done
}

# --------------------------------------------------------------------
# Claude context-chip sweep (see tmux.conf "pane borders" block)
# --------------------------------------------------------------------
# Claude Code publishes its context-usage % into the pane-local @claude_ctx
# option via its statusline script; its SessionEnd hook clears it on normal
# exit. When claude dies without the hook (SIGKILL, crash), the chip and the
# border row would linger — but the shell prompt coming back IS the signal
# that the pane's foreground program is gone... unless it's merely SUSPENDED:
# a stopped job (Ctrl-Z'd claude) keeps its chip, so the sweep skips while
# one exists. One server-side conditional per prompt: a no-op round-trip when
# the pane carries no chip; a clear when it does — which also tombstones the
# recorded session id, so an orphaned statusline subprocess of the dead
# claude can't republish the chip after this cleanup (see tmux-claude-ctx.sh).
if [[ -n ${TMUX_PANE:-} ]]; then
  _claude_ctx_sweep() {
    # only a suspended CLAUDE job exempts the sweep — matching any stopped
    # job would let a ^Z'd editor disable hard-kill cleanup here forever.
    # Anchored to the two launch spellings: `claude …` directly, or the `x`
    # wrapper function (a function-wrapped command's jobtext is the function
    # invocation, not the underlying command).
    local _j
    for _j in ${(k)jobstates}; do
      [[ $jobstates[$_j] == suspended* && $jobtexts[$_j] == (claude|x)( *|) ]] && return 0
    done
    command tmux if-shell -F -t "$TMUX_PANE" '#{n:@claude_ctx}' \
      "run-shell -b 'bash $HOME/.config/tmux/scripts/tmux-claude-ctx.sh clear $TMUX_PANE'" \
      2>/dev/null
    return 0
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _claude_ctx_sweep
fi
