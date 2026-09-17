# Exact command text comes from this shell, never shared shell history.
# Output stays in tmux scrollback; capturing/copying only happens on request.
cout() {
  emulate -L zsh
  if (( $# )); then
    print -u2 'Usage: cout (inside tmux, after a command finishes)'
    return 2
  fi
  if [[ -z ${TMUX:-} || -z ${TMUX_PANE:-} ]]; then
    print -u2 'cout: run this inside tmux.'
    return 1
  fi
  command python3 "$HOME/.config/tmux/scripts/tmux-cout.py" --pane "$TMUX_PANE"
}

_cout_preexec() {
  emulate -L zsh
  # A standalone cout must not replace the command it is about to copy.
  local -a words=("${(@z)1}")
  if (( ${#words} == 1 )) && [[ $words[1] == cout ]]; then
    return 0
  fi
  _cout_pending=1
  command tmux set-option -p -t "$TMUX_PANE" @cout-ready 0 \; \
    set-option -p -t "$TMUX_PANE" @cout-command "$1" 2>/dev/null
  return 0
}

_cout_precmd() {
  emulate -L zsh
  if (( _cout_pending )); then
    _cout_pending=0
    _cout_ready=1
    _cout_skip=0
  elif (( _cout_ready )); then
    # Also count empty/cancelled prompts. Each produces another prompt marker.
    (( ++_cout_skip ))
  fi
  command tmux set-option -p -t "$TMUX_PANE" @cout-ready "$_cout_ready" \; \
    set-option -p -t "$TMUX_PANE" @cout-skip "$_cout_skip" 2>/dev/null
  return 0
}

_cout_setup() {
  emulate -L zsh
  [[ -o interactive && -n ${TMUX:-} && -n ${TMUX_PANE:-} ]] || return 0
  typeset -g _cout_pending=0 _cout_ready=0 _cout_skip=0
  command tmux set-option -p -t "$TMUX_PANE" @cout-ready 0 2>/dev/null
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _cout_preexec
  add-zsh-hook precmd _cout_precmd
}
