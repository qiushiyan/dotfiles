# shellcheck shell=bash
# statusline-rex.sh — the Claude statusline's Rex half: the pane chip as the
# terminal title, which Rex draws in the pane header ("✳ <conversation> ·
# 37% · qiushi · opus-5:high · 5h:23 7d:41"). The Rex lab's counterpart of the
# tmux border chip (docs/rex.md; tmux/.config/tmux/scripts/context-chip.md).
# Sourced by statusline-command.sh after statusline-chip.sh, only inside Rex
# (REX_BLOCK), and reads what the chip computed: PERCENT_USED SESSION_ID
# MODEL_ID EFFORT FIVE_HOUR SEVEN_DAY ACCOUNT WEEK_PCT WEEK_MODEL. Prints
# nothing.
#
# The title belongs to whoever writes it last, so this writes it only when
# Claude was told to leave it alone (CLAUDE_CODE_DISABLE_TERMINAL_TITLE,
# which zsh/.config/zsh/rex.zsh exports inside Rex), and then carries the
# conversation name Claude's own title showed. A title has no colours: a
# figure at 90 or more carries a "!" instead of the border's red.
#
# The render budget is the chip's: builtins on the steady path. Three things
# need a process, and each runs once or in the background: the tty, found
# once per session by walking up to Claude; the conversation name, re-read
# from the transcript in the background at most every 20 seconds; and the
# title write itself, a printf, done only when the text changed.

[ "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-}" = 1 ] && [ "${SESSION_ID:--}" != "-" ] && {
    rex_dir="$HOME/.cache/claude-ctx/rex"
    [ -d "$rex_dir" ] || mkdir -p "$rex_dir" 2>/dev/null
    rex_now="${EPOCHSECONDS:-$(date +%s)}"

    # The terminal Claude runs in. The statusline's own output is captured,
    # and it may have no controlling terminal, so the tty is the nearest
    # ancestor's, remembered per session.
    rex_tty=""
    [ -r "$rex_dir/$SESSION_ID.tty" ] && read -r rex_tty < "$rex_dir/$SESSION_ID.tty"
    if [ -z "$rex_tty" ] || [ ! -w "$rex_tty" ]; then
        rex_pid=$PPID rex_tty=""
        for _ in 1 2 3 4 5; do
            [ "${rex_pid:-1}" -gt 1 ] || break
            rex_t=$(ps -o tty= -p "$rex_pid" 2>/dev/null); rex_t="${rex_t// /}"
            if [ -n "$rex_t" ] && [ "$rex_t" != "??" ] && [ -w "/dev/$rex_t" ]; then
                rex_tty="/dev/$rex_t"; break
            fi
            rex_pid=$(ps -o ppid= -p "$rex_pid" 2>/dev/null); rex_pid="${rex_pid// /}"
        done
        [ -n "$rex_tty" ] && printf '%s\n' "$rex_tty" > "$rex_dir/$SESSION_ID.tty"
    fi

    # The conversation's name: the newest /rename (customTitle), else the
    # newest name Claude gave it (aiTitle), from the session's transcript.
    # Read from the cache file; refreshed in the background once it is 20s
    # old, stamping the attempt first so sibling renders do not pile up.
    rex_name="" rex_at=0
    if [ -r "$rex_dir/$SESSION_ID.name" ]; then
        read -r rex_at rex_name < "$rex_dir/$SESSION_ID.name"
        case "$rex_at" in ''|*[!0-9]*) rex_at=0 ;; esac
    fi
    if [ "$((rex_now - rex_at))" -gt 20 ]; then
        printf '%s %s\n' "$rex_now" "$rex_name" > "$rex_dir/$SESSION_ID.name"
        (
            for rex_t in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/projects/*/"$SESSION_ID".jsonl; do
                [ -r "$rex_t" ] || continue
                rex_n=$(grep -o '"customTitle":"[^"]*"' "$rex_t" | tail -1)
                [ -n "$rex_n" ] || rex_n=$(tail -c 2000000 "$rex_t" | grep -o '"aiTitle":"[^"]*"' | tail -1)
                rex_n="${rex_n#*\":\"}"; rex_n="${rex_n%\"}"
                printf '%s %s\n' "$rex_now" "$rex_n" > "$rex_dir/$SESSION_ID.name"
                break
            done
        ) >/dev/null 2>&1 3<&- 4<&- 5<&- &
    fi

    # The chip: context first after the name, then the tmux border's order of
    # priority, so a header too narrow for all of it loses the least telling
    # end. "-" and empty fields draw nothing.
    rex_mark() { [ "${1:-0}" -ge 90 ] 2>/dev/null && printf '!'; }
    rex_text="✳ ${rex_name:-Claude}"
    [ "${#rex_text}" -gt 50 ] && rex_text="${rex_text:0:49}…"
    rex_text+=" · ${PERCENT_USED}%$(rex_mark "$PERCENT_USED")"
    [ -n "$ACCOUNT" ] && rex_text+=" · $ACCOUNT"
    if [ -n "$MODEL_ID" ] && [ "$MODEL_ID" != "-" ]; then
        rex_text+=" · $MODEL_ID"
        [ -n "$EFFORT" ] && [ "$EFFORT" != "-" ] && rex_text+=":$EFFORT"
    fi
    rex_q=""
    [ -n "$FIVE_HOUR" ] && [ "$FIVE_HOUR" != "-" ] && rex_q+=" 5h:$FIVE_HOUR$(rex_mark "$FIVE_HOUR")"
    [ -n "$SEVEN_DAY" ] && [ "$SEVEN_DAY" != "-" ] && rex_q+=" 7d:$SEVEN_DAY$(rex_mark "$SEVEN_DAY")"
    [ -n "$rex_q" ] && rex_text+=" ·$rex_q"
    [ -n "$WEEK_PCT" ] && [ -n "$WEEK_MODEL" ] && rex_text+=" · $WEEK_MODEL:$WEEK_PCT$(rex_mark "$WEEK_PCT")"

    # Written only when it changed: this runs ~3×/second while Claude streams.
    rex_last=""
    [ -r "$rex_dir/$SESSION_ID.title" ] && IFS= read -r rex_last < "$rex_dir/$SESSION_ID.title"
    if [ -n "$rex_tty" ] && [ "$rex_text" != "$rex_last" ]; then
        printf '\033]0;%s\007' "$rex_text" > "$rex_tty" 2>/dev/null &&
            printf '%s\n' "$rex_text" > "$rex_dir/$SESSION_ID.title"
    fi
}
