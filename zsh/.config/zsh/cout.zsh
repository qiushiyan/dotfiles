# Command records belong to a shell session; the pane recorder owns output.
# The `cout` binary on PATH (~/dev/cout, whose README owns the design) is the
# recorder and the copy command; these hooks mark where each command starts
# and ends in the pane's output stream. The pane is a tmux pane or a Rex block.

_cout_mark() {
  # Private OSC frames travel in the same ordered byte stream as program output.
  # Ordinary OSC 133 prompts from nested/remote shells are just recorded text.
  print -rn -- $'\e]777;cout;'"${_cout_store:t};$1"$'\a'
}

_cout_preexec() {
  emulate -L zsh
  (( _cout_broken )) && return 0
  local -a words=("${(@z)1}")
  local word copying=0
  if [[ $words[1] == cout ]]; then
    copying=1
    for word in "${words[@]}"; do
      case $word in
        ';'|'&'|'&&'|'|'|'||'|$'\n') copying=0 ;;
      esac
    done
  fi
  # cout is standalone; inside a compound command the readiness gate refuses it.
  (( copying )) && return 0
  (( _cout_rex )) || command tmux set-option -p -t "$TMUX_PANE" @cout-ready 0 2>/dev/null
  if [[ -z $_cout_store ]] && ! _cout_start; then
    _cout_broken=1
    return 0
  fi
  (( _cout_rex )) && _cout_publish 0
  (( ++_cout_sequence ))
  _cout_last="$_cout_session-$_cout_sequence"
  # The command text and the directory it runs from, both in place before the
  # start marker.
  if ! (umask 077; print -rn -- "$1" > "$_cout_store/$_cout_last.command" &&
      print -rn -- "$PWD" > "$_cout_store/$_cout_last.cwd") 2>/dev/null; then
    print -u2 'cout: recording stopped; run zshreload to restart it.'
    _cout_pending=0
    _cout_broken=1
    return 0
  fi
  _cout_pending=1
  _cout_mark "B;$_cout_last;${COLUMNS:-80};${LINES:-24}"
  return 0
}

_cout_finish() {
  if (( _cout_pending )); then
    _cout_mark "E;$_cout_last"
    _cout_pending=0
  fi
}

_cout_precmd() {
  emulate -L zsh
  local -a cmds reply
  if (( ! _cout_broken )) && [[ -n $_cout_store ]]; then
    _cout_finish
    # Publish the expected completion ID. Readers wait for that exact record;
    # recorder lag must never make cout silently select the previous command.
    if (( _cout_rex )); then
      _cout_publish 1
    else
      cmds=(set-option -p -t "$TMUX_PANE" @cout-state "$_cout_session $_cout_last" \;
        set-option -p -t "$TMUX_PANE" @cout-ready 1)
    fi
  fi
  # The prompt's other tmux work rides the same round trip, after cout's own
  # publication (tmux-utils.zsh, the agent status sweep).
  if (( _cout_carries_sweep )); then
    _agent_border_sweep_cmds
    if (( $#reply )); then
      (( $#cmds )) && cmds+=(\;)
      cmds+=("${reply[@]}")
    fi
  fi
  (( $#cmds )) && command tmux "${cmds[@]}" 2>/dev/null
  return 0
}

# A Rex block has no pane options, so the shell's state goes to the store as
# "<ready> <session> <latest id>", replaced by rename so a copy never reads
# half of it. zf_mv is zsh/files' mv as a builtin: the prompt forks nothing.
_cout_publish() {
  print -rn -- "$1 $_cout_session $_cout_last" > "$_cout_store/state.tmp" &&
    zf_mv -f "$_cout_store/state.tmp" "$_cout_store/state"
} 2>/dev/null

_cout_start() {
  emulate -L zsh
  local -a setup=("${(@f)$(command cout setup --pane "$_cout_pane")}")
  (( ${#setup} == 2 )) || return 1
  typeset -g _cout_store=$setup[1] _cout_session=$setup[2]
  _cout_mark "S;$_cout_session;$$"
}

_cout_setup() {
  emulate -L zsh
  [[ -o interactive ]] || return 0
  # Each multiplexer sets TERM_PROGRAM for its own children, so it names the
  # innermost when a tmux client runs in a Rex block or a Rex server was
  # started from a tmux pane; cout picks its default pane the same way.
  local pane rex=0
  if [[ $TERM_PROGRAM == rex && -n ${REX_BLOCK:-} ]]; then
    pane=$REX_BLOCK rex=1
    zmodload -F zsh/files b:zf_mv || return 0
  elif [[ -n ${TMUX:-} && -n ${TMUX_PANE:-} ]]; then
    pane=$TMUX_PANE
  else
    return 0
  fi
  # Initialize on the first real command, keeping setup's process and tmux
  # round trips out of shell startup.
  typeset -g _cout_store='' _cout_session='' _cout_pending=0 _cout_pane=$pane _cout_rex=$rex
  typeset -g _cout_sequence=0 _cout_last=- _cout_broken=0 _cout_carries_sweep=0
  (( rex )) || command tmux set-option -p -t "$TMUX_PANE" @cout-ready 0 2>/dev/null
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _cout_preexec
  add-zsh-hook precmd _cout_precmd
  add-zsh-hook zshexit _cout_finish
  # One tmux round trip per prompt: this hook runs after oh-my-posh's, so it
  # takes over the agent status sweep (tmux-utils.zsh) and chains it behind
  # its own publication; the standalone sweep hook would be a second trip.
  if (( ! rex && $+functions[_agent_border_sweep_cmds] )); then
    add-zsh-hook -d precmd _agent_border_sweep
    _cout_carries_sweep=1
  fi
}
