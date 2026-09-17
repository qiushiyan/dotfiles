# Exact command text comes from this shell, never shared shell history.
# Output stays in tmux scrollback; capturing/copying only happens on request.
cout() {
  emulate -L zsh
  local index=${1-1}
  if (( $# > 1 )); then
    print -u2 'Usage: cout [positive index] (default: 1, the last command)'
    return 2
  fi
  if [[ -z ${TMUX:-} || -z ${TMUX_PANE:-} ]]; then
    print -u2 'cout: run this inside tmux.'
    return 1
  fi
  command python3 "$HOME/.config/tmux/scripts/tmux-cout.py" --pane "$TMUX_PANE" --index "$index"
}

_cout_preexec() {
  emulate -L zsh
  # Ignore standalone cout calls, including invalid arguments. Compound
  # commands such as `cout 2; print done` count as real commands: their cout
  # call is refused while the compound command is running.
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
  (( copying )) && return 0
  _cout_pending=1
  _cout_command=$1
  command tmux set-option -p -t "$TMUX_PANE" @cout-ready 0 2>/dev/null
  return 0
}

_cout_precmd() {
  emulate -L zsh
  (( ++_cout_prompt ))
  local -a update
  if (( _cout_pending )); then
    _cout_pending=0
    _cout_ready=1
    # Bounded per-pane metadata, not output logs. Each entry contains the
    # ending prompt ordinal and exact command, separated by the first newline.
    # Only this writer knows capacity and reuse order; the reader gets an
    # explicit newest-first slot list and never reconstructs ring arithmetic.
    local capacity=1000 slot
    slot=$(( _cout_slot % capacity + 1 ))
    _cout_slot=$slot
    _cout_history=("$slot" "${(@)_cout_history[1,capacity-1]}")
    update=(set-option -p -t "$TMUX_PANE" "@cout-entry-$slot"
      "$_cout_prompt"$'\n'"$_cout_command" ';')
  fi
  # Empty/cancelled prompts and cout notifications advance the prompt ordinal
  # without adding a command entry, so index 2 always means the prior command.
  command tmux "${update[@]}" \
    set-option -p -t "$TMUX_PANE" @cout-history "${(j: :)_cout_history}" \; \
    set-option -p -t "$TMUX_PANE" @cout-prompt "$_cout_prompt" \; \
    set-option -p -t "$TMUX_PANE" @cout-ready "$_cout_ready" 2>/dev/null
  return 0
}

_cout_setup() {
  emulate -L zsh
  [[ -o interactive && -n ${TMUX:-} && -n ${TMUX_PANE:-} ]] || return 0
  typeset -g _cout_pending=0 _cout_ready=0 _cout_slot=0 _cout_prompt=0 _cout_command=''
  typeset -ga _cout_history=()
  command tmux set-option -p -t "$TMUX_PANE" @cout-ready 0 \; \
    set-option -p -t "$TMUX_PANE" @cout-history '' 2>/dev/null
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _cout_preexec
  add-zsh-hook precmd _cout_precmd
}
