# Grok Bot's commands on this machine, for grokbot-transcript. The app keeps the
# bot's tool calls on its own servers, but a command it runs here arrives in a
# shell with CURSOR_AGENT and CURSOR_REQUEST_ID set, the request id being the
# one the chat entries of that turn carry. Such a shell appends a start line
# and an end line to host-commands.jsonl, which grokbot-transcript joins to the
# chat. Every other shell pays one test.
#
# The app runs `$SHELL -c '<wrapper>'`, the same wrapper every time: it reads
# the command from descriptor 5 into $1, evals the state the shell before it
# dumped (every function and export), evals $1, and dumps its own state for
# the next. Three things follow:
#   - the -c string says nothing of the command, so a wrapped start line has
#     an empty cmd and `"wrapped":true`, and the end line carries the command;
#   - the restored exports bring back an older shell's _GROKBOT_HOST_CMD, so
#     the end line's id is written into the trap, not read from the variable;
#   - the restored functions replace this file's by name with whatever version
#     that older shell had, so the trap carries the writer's own text and
#     calls nothing by name.
# A plain `$SHELL -c '<command>'` logs its command on the start line.
if [[ -n ${CURSOR_AGENT-} && -n ${CURSOR_REQUEST_ID-} && -n ${ZSH_EXECUTION_STRING-} \
      && -z ${_GROKBOT_HOST_CMD-} ]]; then
  # _grokbot_host_line KIND ID [NAME VALUE]...: one line of the log. `status`
  # and `wrapped` go as written, every other value as a JSON string with any
  # control character it cannot escape as `?`; a cmd stops at 16,000
  # characters. Whole in one function, since the trap below carries its text.
  _grokbot_host_line() {
    emulate -L zsh
    zmodload zsh/datetime 2>/dev/null
    zmodload -F zsh/files b:zf_mkdir b:zf_chmod 2>/dev/null || return 0
    zmodload -F zsh/system b:sysopen b:syswrite 2>/dev/null || return 0
    local dir=${GROKBOT_ARCHIVE_DIR:-$HOME/.local/state/grokbot}
    local file=$dir/host-commands.jsonl ms line k v
    local -i fd
    printf -v ms '%.0f' $(( EPOCHREALTIME * 1000 ))
    line="{\"t\":\"$1\",\"id\":\"$2\",\"at_ms\":$ms"
    shift 2
    for k v in "$@"; do
      case $k in
        status|wrapped) line+=",\"$k\":$v" ;;
        *)
          if [[ $k == cmd ]] && (( ${#v} > 16000 )); then
            v=${v[1,16000]}; line+=',"truncated":true'
          fi
          v=${v//\\/\\\\}; v=${v//\"/\\\"}
          v=${v//$'\n'/\\n}; v=${v//$'\t'/\\t}; v=${v//$'\r'/\\r}
          line+=",\"$k\":\"${v//[[:cntrl:]]/?}\"" ;;
      esac
    done
    line+='}'
    {
      if [[ ! -e $file ]]; then
        zf_mkdir -p -m 700 $dir && print -n >> $file && zf_chmod 600 $file
      fi
      # One write(2) on an append descriptor: `print` flushes a long line in
      # pieces, and two shells' pieces interleave.
      if sysopen -a -w -u fd $file; then
        syswrite -o $fd -- "$line"$'\n'
        exec {fd}>&-
      fi
    } 2>/dev/null
    return 0
  }
  typeset -i _grokbot_wrapped=0
  [[ ${ZSH_EXECUTION_STRING[1,200]} == *'__cursor_command <&5'* ]] && _grokbot_wrapped=1
  () {
    emulate -L zsh
    zmodload zsh/datetime 2>/dev/null
    # Exported, so the shells this command starts in turn log nothing.
    export _GROKBOT_HOST_CMD=$$-${EPOCHREALTIME/./}
    local -a said=(cmd $ZSH_EXECUTION_STRING)
    (( _grokbot_wrapped )) && said=(cmd '' wrapped true)
    _grokbot_host_line start $_GROKBOT_HOST_CMD request_id $CURSOR_REQUEST_ID \
      conversation_id "${CURSOR_CONVERSATION_ID-}" cwd $PWD "${said[@]}"
  }
  # An EXIT trap, not zshexit: zsh runs a lone last command by exec'ing it,
  # which skips zshexit, and a trap on EXIT turns that off. The shell still
  # exits with the command's status. Set out here, since one set in a function
  # runs when that function returns.
  if (( _grokbot_wrapped )); then
    trap "() { ${functions[_grokbot_host_line]} } end $_GROKBOT_HOST_CMD status \$? cmd \"\${1-}\"" EXIT
  else
    trap "() { ${functions[_grokbot_host_line]} } end $_GROKBOT_HOST_CMD status \$?" EXIT
  fi
  unset _grokbot_wrapped
fi
