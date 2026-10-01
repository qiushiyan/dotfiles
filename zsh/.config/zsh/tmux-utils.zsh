# ~/.config/zsh/tmux-utils.zsh
# Codex's pane-border wrapper and the prompt's agent-status sweep

# --------------------------------------------------------------------
# codex - Put Codex's work and runtime state on the pane border
# --------------------------------------------------------------------
# Codex can put its model, effort, context and rate limits in the terminal
# title, which tmux records as #{pane_title}. Its own footer cannot truncate one
# item independently, so a long current-dir used to erase the branch/PR at the
# right edge. Publish a compact path separately: linked worktrees resolve to
# their main checkout (~/dev/.worktrees/main/feat/x -> planlab/main), ~/dev is
# implicit, and other home paths use ~ — the Claude statusline's convention,
# from the one definition both source (tmux scripts/lib/display-path.sh). The
# Codex footer already shows the branch. Non-interactive calls and calls
# outside tmux pass through.
_codex_display_path() {
  emulate -L zsh
  local _codex_dir=${1:-$PWD} _codex_home DISPLAY_PATH DISPLAY_PATH_LINKED
  local -a _codex_git_dirs

  if [[ $_codex_dir != /* ]]; then
    _codex_dir="$PWD/$_codex_dir"
  fi
  _codex_dir=$(builtin cd -q -- "$_codex_dir" 2>/dev/null && pwd -P) || return 1
  _codex_home=$(builtin cd -q -- "$HOME" 2>/dev/null && pwd -P) || _codex_home=$HOME

  _codex_git_dirs=("${(@f)$(command git -C "$_codex_dir" rev-parse \
    --path-format=absolute --git-dir --git-common-dir --show-toplevel 2>/dev/null)}")
  source "$HOME/.config/tmux/scripts/lib/display-path.sh" || return 1
  display_path "$_codex_dir" "$_codex_home" \
    "${_codex_git_dirs[1]-}" "${_codex_git_dirs[2]-}" "${_codex_git_dirs[3]-}"
  print -r -- "$DISPLAY_PATH"
}

# _codex_in_pane <n> <launcher word 1..n> [codex args...]
# Run a Codex launcher with the pane decoration around it. The launcher is
# whatever starts the session — `command codex` for the plain spelling,
# `headroom launch --vendor codex [--account <name>] --` for the managed one
# (codex.zsh) — and the first <n> words are it; the rest are Codex's own
# arguments, which is where -C/--cd is looked for. One implementation, so a
# managed session and a plain one look the same on the border.
_codex_in_pane() {
  emulate -L zsh
  local -i _codex_n=$1; shift
  local -a _codex_launcher=("${(@)argv[1,_codex_n]}")
  shift $_codex_n
  if [[ ! -o interactive || -z ${TMUX_PANE:-} ]]; then
    "${_codex_launcher[@]}" "$@"
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
  local _codex_status=$HOME/.config/tmux/scripts/tmux-agent-status.sh

  # The owner (tmux-agent-status.sh) knows which options mark Codex's lifetime;
  # the wrapper only says when it starts and ends. Synchronous, so the marker
  # is gone before the next prompt's sweep looks for it.
  command bash "$_codex_status" activate codex "$_codex_path" "$_codex_pane" 2>/dev/null

  "${_codex_launcher[@]}" "$@" || _codex_rc=$?

  command bash "$_codex_status" clear codex "$_codex_pane" 2>/dev/null
  return $_codex_rc
}

# Plain `codex`: the vendor's own default account (~/.codex), decorated. The
# headroom-aware spelling is `cx` (codex.zsh).
codex() {
  emulate -L zsh
  _codex_in_pane 2 command codex "$@"
}

# --------------------------------------------------------------------
# Agent status sweep on every prompt (see tmux.conf "pane borders" block)
# --------------------------------------------------------------------
# Claude Code publishes its chip through its statusline and clears it from
# its SessionEnd hook; the codex wrapper above marks Codex's lifetime. When an
# agent dies without its own cleanup (SIGKILL, crash, interrupt), the shell
# prompt coming back IS the signal that it no longer owns the pane... unless
# it is merely SUSPENDED: a stopped job keeps its status, so that agent is
# left out of the sweep while one exists.
#
# The prompt path stays one server-side conditional: a no-op when no listed
# agent's presence marker is set, and only on a hit a background run of the
# owner's `sweep` verb, which drops the state (Claude's drop tombstones the
# recorded session, so an orphaned statusline subprocess of the dead claude
# cannot republish afterwards) and reconciles the border. The option names
# come from the vocabulary the owner uses (lib/agent-vocab.sh).
#
# _agent_border_sweep_cmds leaves the tmux argv in $reply rather than running
# it, so the prompt's one tmux round trip can carry it: cout's precmd, which
# runs after oh-my-posh's, chains its own publication in front and drops this
# standalone hook (cout.zsh, _cout_setup). Without cout, _agent_border_sweep
# runs it alone.
if [[ -o interactive && -n ${TMUX_PANE:-} &&
      -r $HOME/.config/tmux/scripts/lib/agent-vocab.sh ]]; then
  source "$HOME/.config/tmux/scripts/lib/agent-vocab.sh"

  _agent_border_sweep_cmds() {
    reply=()
    # Only a suspended job of the agent itself exempts it — matching any
    # stopped job would let a ^Z'd editor disable hard-kill cleanup forever.
    # Claude is anchored to its two launch spellings: `claude …` directly, or
    # the `x` wrapper function (a function-wrapped command's jobtext is the
    # function invocation, not the underlying command).
    local _j _claude_suspended=0 _codex_suspended=0 _cond= _agents=
    for _j in ${(k)jobstates}; do
      [[ $jobstates[$_j] == suspended* ]] || continue
      [[ $jobtexts[$_j] == (claude|x)( *|) ]] && _claude_suspended=1
      [[ $jobtexts[$_j] == codex( *|) ]] && _codex_suspended=1
    done
    if (( ! _claude_suspended )); then
      _cond="#{n:$AGENT_CLAUDE_PRESENCE}"; _agents=claude
    fi
    if (( ! _codex_suspended )); then
      if [[ -n $_cond ]]; then
        _cond="#{||:$_cond,#{n:$AGENT_CODEX_PRESENCE}}"; _agents+=" codex"
      else
        _cond="#{n:$AGENT_CODEX_PRESENCE}"; _agents=codex
      fi
    fi
    [[ -n $_cond ]] || return 0
    reply=(if-shell -F -t "$TMUX_PANE" "$_cond"
      "run-shell -b 'bash $AGENT_STATUS_BIN sweep $TMUX_PANE $_agents'")
  }

  _agent_border_sweep() {
    local -a reply
    _agent_border_sweep_cmds
    (( $#reply )) && command tmux "${reply[@]}" 2>/dev/null
    return 0
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _agent_border_sweep
fi
