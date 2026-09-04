# ~/.config/zsh/tmux-utils.zsh
# tmux helper functions for scripting panes (used by pair-coding skill)

# --------------------------------------------------------------------
# codex - Put Codex's work and runtime state on the pane border
# --------------------------------------------------------------------
# Codex can put its model, effort, context and rate limits in the terminal
# title, which tmux records as #{pane_title}. Its own footer cannot truncate one
# item independently, so a long current-dir used to erase the branch/PR at the
# right edge. Publish a compact path separately: linked worktrees resolve to
# their main checkout (~/dev/.worktrees/main/feat/x -> planlab/main), ~/dev is
# implicit, and other home paths use ~. This is the same path convention as the
# Claude statusline. Non-interactive calls and calls outside tmux pass through.
_codex_display_path() {
  emulate -L zsh
  local _codex_dir=${1:-$PWD} _codex_display _codex_git_dir _codex_home
  local _codex_git_common _codex_toplevel
  local -a _codex_git_dirs

  if [[ $_codex_dir != /* ]]; then
    _codex_dir="$PWD/$_codex_dir"
  fi
  _codex_dir=$(builtin cd -q -- "$_codex_dir" 2>/dev/null && pwd -P) || return 1
  _codex_home=$(builtin cd -q -- "$HOME" 2>/dev/null && pwd -P) || _codex_home=$HOME
  _codex_display=$_codex_dir

  _codex_git_dirs=("${(@f)$(command git -C "$_codex_dir" rev-parse \
    --path-format=absolute --git-dir --git-common-dir --show-toplevel 2>/dev/null)}")
  if (( ${#_codex_git_dirs} >= 3 )); then
    _codex_git_dir=${_codex_git_dirs[1]}
    _codex_git_common=${_codex_git_dirs[2]}
    _codex_toplevel=${_codex_git_dirs[3]}
    if [[ -n $_codex_git_common && -n $_codex_toplevel && \
          $_codex_git_dir != $_codex_git_common ]]; then
      # Preserve a cwd below the worktree root, but do not repeat the branch:
      # the Codex footer already owns that label.
      _codex_display="${_codex_git_common%/.git}${_codex_dir#"$_codex_toplevel"}"
    fi
  fi

  if [[ $_codex_display == "$_codex_home/dev/"* ]]; then
    _codex_display=${_codex_display#"$_codex_home/dev/"}
  elif [[ $_codex_display == "$_codex_home" ]]; then
    _codex_display='~'
  elif [[ $_codex_display == "$_codex_home/"* ]]; then
    _codex_display="~/${_codex_display#"$_codex_home/"}"
  fi
  print -r -- "$_codex_display"
}

codex() {
  emulate -L zsh
  if [[ ! -o interactive || -z ${TMUX_PANE:-} ]]; then
    command codex "$@"
    return $?
  fi

  local _codex_pane=$TMUX_PANE _codex_rc=0 _codex_dir=$PWD
  local -a _codex_args=("$@")
  local -i _codex_i
  for (( _codex_i = 1; _codex_i <= ${#_codex_args}; _codex_i++ )); do
    case ${_codex_args[_codex_i]} in
      -C|--cd)
        (( _codex_i < ${#_codex_args} )) && _codex_dir=${_codex_args[_codex_i + 1]}
        ;;
      --cd=*) _codex_dir=${_codex_args[_codex_i]#--cd=} ;;
    esac
  done
  local _codex_path=$(_codex_display_path "$_codex_dir")

  command tmux set-option -p -t "$_codex_pane" @codex_path "$_codex_path" 2>/dev/null
  command tmux set-option -p -t "$_codex_pane" @codex_active 1 2>/dev/null
  command tmux set-option -w -t "$_codex_pane" pane-border-status top 2>/dev/null

  command codex "$@" || _codex_rc=$?

  command tmux set-option -p -u -t "$_codex_pane" @codex_active 2>/dev/null
  command tmux set-option -p -u -t "$_codex_pane" @codex_path 2>/dev/null
  command tmux run-shell -b \
    "bash '$HOME/.config/tmux/scripts/tmux-claude-ctx.sh' reconcile '$_codex_pane'" \
    2>/dev/null
  return $_codex_rc
}

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
# Agent pane-border sweep (see tmux.conf "pane borders" block)
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
# The codex wrapper normally clears @codex_active itself; the prompt sweep is
# its interrupt/crash backstop. A suspended agent keeps its own marker.
if [[ -n ${TMUX_PANE:-} ]]; then
  _agent_border_sweep() {
    # only a suspended CLAUDE job exempts the sweep — matching any stopped
    # job would let a ^Z'd editor disable hard-kill cleanup here forever.
    # Anchored to the two launch spellings: `claude …` directly, or the `x`
    # wrapper function (a function-wrapped command's jobtext is the function
    # invocation, not the underlying command).
    local _j _claude_suspended=0 _codex_suspended=0
    for _j in ${(k)jobstates}; do
      [[ $jobstates[$_j] == suspended* ]] || continue
      [[ $jobtexts[$_j] == (claude|x)( *|) ]] && _claude_suspended=1
      [[ $jobtexts[$_j] == codex( *|) ]] && _codex_suspended=1
    done
    if (( ! _claude_suspended )); then
      command tmux if-shell -F -t "$TMUX_PANE" '#{n:@claude_ctx}' \
        "run-shell -b 'bash $HOME/.config/tmux/scripts/tmux-claude-ctx.sh clear $TMUX_PANE'" \
        2>/dev/null
    fi
    if (( ! _codex_suspended )); then
      command tmux if-shell -F -t "$TMUX_PANE" '#{n:@codex_active}' \
        "set-option -p -u -t '$TMUX_PANE' @codex_active ; set-option -p -u -t '$TMUX_PANE' @codex_path ; run-shell -b 'bash $HOME/.config/tmux/scripts/tmux-claude-ctx.sh reconcile $TMUX_PANE'" \
        2>/dev/null
    fi
    return 0
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _agent_border_sweep
fi
