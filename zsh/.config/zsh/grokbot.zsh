# Grok Bot's commands on this machine, for grokbot-transcript. The app keeps the
# bot's tool calls on its own servers, but a command it runs here arrives as
# `$SHELL -c '<command>'` with CURSOR_AGENT and CURSOR_REQUEST_ID set, the
# request id being the one the chat entries of that turn carry. Such a shell
# appends a start line and an end line to host-commands.jsonl, which
# grokbot-transcript joins to the chat. Every other shell pays one test.
if [[ -n ${CURSOR_AGENT-} && -n ${CURSOR_REQUEST_ID-} && -n ${ZSH_EXECUTION_STRING-} \
      && -z ${_GROKBOT_HOST_CMD-} ]]; then
  _grokbot_host_log() {
    emulate -L zsh
    local dir=${GROKBOT_ARCHIVE_DIR:-$HOME/.local/state/grokbot}
    local file=$dir/host-commands.jsonl ms
    {
      printf -v ms '%.0f' $(( EPOCHREALTIME * 1000 ))
      if [[ ! -e $file ]]; then
        zf_mkdir -p -m 700 $dir && print -n >> $file && zf_chmod 600 $file
      fi
      print -r -- "{\"t\":\"$1\",\"id\":\"$_GROKBOT_HOST_CMD\",\"at_ms\":$ms,$2}" >> $file
    } 2>/dev/null
    return 0
  }
  # A JSON string in REPLY: escapes, then any other control character as `?`.
  _grokbot_json() {
    emulate -L zsh
    local s=$1
    s=${s//\\/\\\\}; s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}; s=${s//$'\t'/\\t}; s=${s//$'\r'/\\r}
    REPLY="\"${s//[[:cntrl:]]/?}\""
  }
  () {
    emulate -L zsh
    zmodload zsh/datetime 2>/dev/null
    zmodload -F zsh/files b:zf_mkdir b:zf_chmod 2>/dev/null || return 0
    # Exported, so the shells this command starts in turn log nothing.
    export _GROKBOT_HOST_CMD=$$-${EPOCHREALTIME/./}
    local cmd=$ZSH_EXECUTION_STRING more=
    (( ${#cmd} > 16000 )) && { cmd=${cmd[1,16000]}; more=',"truncated":true' }
    local rid cid wd text
    _grokbot_json $CURSOR_REQUEST_ID; rid=$REPLY
    _grokbot_json ${CURSOR_CONVERSATION_ID-}; cid=$REPLY
    _grokbot_json $PWD; wd=$REPLY
    _grokbot_json $cmd; text=$REPLY
    _grokbot_host_log start "\"request_id\":$rid,\"conversation_id\":$cid,\"cwd\":$wd,\"cmd\":$text$more"
  }
  # An EXIT trap, not zshexit: zsh runs a lone last command by exec'ing it,
  # which skips zshexit, and a trap on EXIT turns that off. The shell still
  # exits with the command's status.
  trap '_grokbot_host_log end "\"status\":$?"' EXIT
fi
