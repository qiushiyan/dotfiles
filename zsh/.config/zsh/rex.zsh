# Rex (an experiment, ~/dotfiles/docs/rex.md): an interactive shell inside
# Rex makes sure the lab's background watcher, rexd, runs on the server; it
# numbers the tabs. Detached, so startup does not wait for it.
if [[ -o interactive && -n $REX_BLOCK ]] && (( $+commands[rexd] )); then
  rexd &>/dev/null &!
fi

# Claude Code does not know TERM_PROGRAM=rex, so it prints URLs as plain text
# unless told the terminal takes OSC 8 links. On the mini this was set only by
# accident, by the server's inherited SSH variables (hosts/mini.zsh).
[[ -n $REX_BLOCK ]] && export FORCE_HYPERLINK=1

# Commands as program status (OSC 7501, id=shell), as agents report theirs: a
# command shows as working on its tab's badge and the board while it runs; one
# that ran REX_JOB_MIN seconds or more stays done or error until the next
# command, so prefix a and the board find a finished build as they find an
# agent, and rexd notifies when its tab is out of view. Interactive programs
# (editors, agents, pagers, ssh) report nothing. zsh hands every precmd hook
# the command's status, so this one disturbs no other.
if [[ -o interactive && -n $REX_BLOCK ]]; then
  typeset -g _rex_job_cmd='' _rex_job_start=0 _rex_job_shown=0
  : ${REX_JOB_MIN:=10}
  zmodload zsh/datetime

  _rex_job_emit() {
    print -n -- $'\e]7501;'"$1"$'\e\\'
  }

  _rex_job_b64() {
    print -rn -- "$1" | base64 | tr -d '\n'
  }

  _rex_job_preexec() {
    emulate -L zsh
    local word=${${(z)1}[1]}
    case $word in
      n|nvim|vim|vi|view|claude|codex|ssh|mosh|lazygit|lg|less|more|man|htop|btop|top|yazi|tig|fzf|tmux|rex|watch)
        word='' ;;
    esac
    # The Claude launchers (x and its per-account siblings, claude.zsh).
    [[ -n $word && $functions[$word] == *_claude_* ]] && word=''
    if [[ -z $word ]]; then
      _rex_job_cmd=''
      (( _rex_job_shown )) && _rex_job_emit 'state=clear:id=shell'
      _rex_job_shown=0
      return 0
    fi
    _rex_job_cmd=$1 _rex_job_start=$EPOCHSECONDS _rex_job_shown=1
    _rex_job_emit "state=working:id=shell:app=shell:title=$(_rex_job_b64 ${PWD:t}):msg=$(_rex_job_b64 $1)"
  }

  _rex_job_precmd() {
    local rc=$?
    emulate -L zsh
    [[ -n $_rex_job_cmd ]] || return 0
    local took=$(( EPOCHSECONDS - _rex_job_start ))
    # Short commands and ctrl-c leave nothing behind.
    if (( took < REX_JOB_MIN || rc == 130 )); then
      _rex_job_emit 'state=clear:id=shell'
      _rex_job_shown=0
    else
      local state=done msg="${_rex_job_cmd[1,80]} · ${took}s"
      (( rc )) && state=error msg+=" · exit $rc"
      _rex_job_emit "state=$state:id=shell:app=shell:title=$(_rex_job_b64 ${PWD:t}):msg=$(_rex_job_b64 $msg)"
    fi
    _rex_job_cmd=''
    return 0
  }

  _rex_job_exit() {
    (( _rex_job_shown )) && _rex_job_emit 'state=clear:id=shell'
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _rex_job_preexec
  add-zsh-hook precmd _rex_job_precmd
  add-zsh-hook zshexit _rex_job_exit
fi
