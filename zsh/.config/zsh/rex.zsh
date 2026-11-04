# Rex (an experiment, ~/dotfiles/docs/rex.md): an interactive shell inside
# Rex makes sure the lab's background watcher, rexd, runs on the server; it
# numbers the tabs. Detached, so startup does not wait for it.
if [[ -o interactive && -n $REX_BLOCK ]] && (( $+commands[rexd] )); then
  rexd &>/dev/null &!
fi

# A pane Rex restored is a plain shell in its directory. If the pane has a
# record, its program comes back as a line entered at the first prompt, as if
# typed: the launchers exist by then, and the line shows what ran. rex-resume
# decides, and says nothing unless the server that wrote the record is gone.
_rex_pane_record="${XDG_STATE_HOME:-$HOME/.local/state}/rex-lab/panes/${REX_BLOCK//:/_}.json"
if [[ -o interactive && -n $REX_BLOCK && -e $_rex_pane_record ]]; then
  _rex_resume_line() {
    add-zle-hook-widget -d zle-line-init _rex_resume_line
    local -a out
    out=("${(@f)$($HOME/.local/bin/rex-resume line 2>/dev/null)}")
    (( $#out == 3 )) || return 0
    builtin cd -q -- $out[1] 2>/dev/null
    [[ -n $out[2] ]] && export $out[2]
    BUFFER=$out[3]
    zle accept-line
  }
  autoload -Uz add-zle-hook-widget
  zle -N _rex_resume_line
  add-zle-hook-widget zle-line-init _rex_resume_line
fi
unset _rex_pane_record

# Claude Code does not know TERM_PROGRAM=rex, so it prints URLs as plain text
# unless told the terminal takes OSC 8 links. .zshenv takes it back out of the
# shells Claude Code runs its tools in.
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

  # _rex_job_text TEXT N: TEXT as Rex keeps it, in REPLY. Rex discards a whole
  # report whose text holds a control character or passes its limits (msg
  # 2048 bytes), so a multi-line or pasted command would lose its badge:
  # every control character becomes a space and the text stops at N
  # characters. Multibyte on, so a C1 control goes whole.
  _rex_job_text() {
    emulate -L zsh
    REPLY=${1//[[:cntrl:]]/ }
    REPLY=${REPLY[1,$2]}
  }

  # _rex_job_b64 TEXT: base64 of TEXT's bytes, in REPLY. In the shell, not
  # base64(1): it runs before every command, and two forks there cost ~12 ms.
  _rex_job_b64() {
    emulate -L zsh -o no_multibyte
    local s=$1 t=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/ c
    local -i i n=$#s a b d w x y z
    REPLY=
    for (( i = 1; i <= n; i += 3 )); do
      c=$s[i] a=0 b=0 d=0; (( a = #c & 255 ))
      if (( i + 1 <= n )); then c=$s[i+1]; (( b = #c & 255 )); fi
      if (( i + 2 <= n )); then c=$s[i+2]; (( d = #c & 255 )); fi
      (( w = (a >> 2) + 1, x = ((a & 3) << 4 | b >> 4) + 1,
         y = ((b & 15) << 2 | d >> 6) + 1, z = (d & 63) + 1 ))
      REPLY+=$t[w]$t[x]
      if (( i + 1 <= n )); then REPLY+=$t[y]; else REPLY+='='; fi
      if (( i + 2 <= n )); then REPLY+=$t[z]; else REPLY+='='; fi
    done
  }

  # _rex_job_fields TITLE MSG: the report's title and msg pairs, in REPLY.
  _rex_job_fields() {
    local title msg
    _rex_job_text "$1" 48; _rex_job_b64 "$REPLY"; title=$REPLY
    _rex_job_text "$2" 200; _rex_job_b64 "$REPLY"; msg=$REPLY
    REPLY="title=$title:msg=$msg"
  }

  _rex_job_preexec() {
    emulate -L zsh
    local word=${${(z)1}[1]}
    case $word in
      n|nvim|vim|vi|view|claude|codex|ssh|mosh|lazygit|lg|less|more|man|htop|btop|top|yazi|tig|fzf|tmux|rex|watch|exec)
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
    _rex_job_fields "${PWD:t}" "$1"
    _rex_job_emit "state=working:id=shell:app=shell:$REPLY"
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
      _rex_job_text "$_rex_job_cmd" 80
      local state=done msg="$REPLY · ${took}s"
      (( rc )) && state=error msg+=" · exit $rc"
      _rex_job_fields "${PWD:t}" "$msg"
      _rex_job_emit "state=$state:id=shell:app=shell:$REPLY"
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
