# Command records belong to a shell session; the pane recorder owns output.
cout() {
  emulate -L zsh
  if (( $# > 1 )); then
    print -u2 'Usage: cout [positive index] (default: 1, the last command)'
    return 2
  fi
  if [[ -z ${TMUX:-} || -z ${TMUX_PANE:-} ]]; then
    print -u2 'cout: run this inside tmux.'
    return 1
  fi
  command python3 "$HOME/.config/tmux/scripts/tmux-cout.py" --pane "$TMUX_PANE" --index "${1-1}"
}

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
  command tmux set-option -p -t "$TMUX_PANE" @cout-ready 0 2>/dev/null
  if [[ -z $_cout_store ]] && ! _cout_start; then
    _cout_broken=1
    return 0
  fi
  (( ++_cout_sequence ))
  _cout_last="$_cout_session-$_cout_sequence"
  if ! (umask 077; print -rn -- "$1" > "$_cout_store/$_cout_last.command") 2>/dev/null; then
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
  (( _cout_broken )) && return 0
  [[ -n $_cout_store ]] || return 0
  _cout_finish
  # Publish the expected completion ID. Readers wait for that exact record;
  # recorder lag must never make cout silently select the previous command.
  command tmux set-option -p -t "$TMUX_PANE" @cout-state "$_cout_session $_cout_last" \; \
    set-option -p -t "$TMUX_PANE" @cout-ready 1 2>/dev/null
  return 0
}

_cout_start() {
  emulate -L zsh
  local -a setup=("${(@f)$(command python3 "$HOME/.config/tmux/scripts/tmux-cout.py" setup --pane "$TMUX_PANE")}")
  (( ${#setup} == 2 )) || return 1
  typeset -g _cout_store=$setup[1] _cout_session=$setup[2]
  _cout_mark "S;$_cout_session;$$"
}

_cout_setup() {
  emulate -L zsh
  [[ -o interactive && -n ${TMUX:-} && -n ${TMUX_PANE:-} ]] || return 0
  # Initialize on the first real command, without adding Python startup or
  # background setup processes to shell startup.
  typeset -g _cout_store='' _cout_session='' _cout_pending=0
  typeset -g _cout_sequence=0 _cout_last=- _cout_broken=0
  command tmux set-option -p -t "$TMUX_PANE" @cout-ready 0 2>/dev/null
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _cout_preexec
  add-zsh-hook precmd _cout_precmd
  add-zsh-hook zshexit _cout_finish
}
