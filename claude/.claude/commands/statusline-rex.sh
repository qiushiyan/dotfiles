# shellcheck shell=bash
# statusline-rex.sh — the Claude statusline's Rex half: in a Rex pane, what
# this session burns goes to the pane header and the floating chip instead of
# a tmux border (rex/.local/bin/rex-chip owns both and documents the state
# file). Sourced by statusline-command.sh after statusline-chip.sh, whose
# QUOTA_LANE, WEEK_PCT and WEEK_MODEL it reads beside the payload's values;
# sets REX_CHIP when the header carries the chip, so the line leaves the
# account to it; prints nothing.
#
# The account is the lane's full email (QUOTA_LANE), never the short label the
# tmux border wears: the header has the room, and an alias has to be learned.
#
# It runs in the render's process, ~3×/second per pane while a session streams,
# so the steady state is one builtin read and a string compare. Only a changed
# value writes the state and starts rex-chip, detached, to set the label.
#
# A tmux client inside a Rex pane keeps the tmux border: TMUX_PANE wins.
#
# REX_CHIP_CMD is a test lever, not a setting, in the shape of
# CLAUDE_CTX_REFRESH_CMD: UNSET (production) means the stowed rex-chip;
# set-but-EMPTY publishes nothing; set to a path substitutes that.
REX_CHIP=""
_rex_chip_cmd="${REX_CHIP_CMD-$HOME/.local/bin/rex-chip}"
if [ -n "${REX_BLOCK:-}" ] && [ -z "${TMUX_PANE:-}" ] && [ "${SESSION_ID:--}" != "-" ] &&
   [ -n "$_rex_chip_cmd" ] && [ -x "$_rex_chip_cmd" ]; then
    REX_CHIP=1
    _rex_chip_dir="${XDG_STATE_HOME:-$HOME/.local/state}/rex-lab/chip"
    _rex_chip_file="$_rex_chip_dir/${REX_BLOCK//:/_}.chip"
    _rex_chip_cols="${COLUMNS:-0}"
    case "$_rex_chip_cols" in ''|*[!0-9]*) _rex_chip_cols=0 ;; esac
    _rex_chip_new="$SESSION_ID"$'\x1f'"$QUOTA_LANE"$'\x1f'"$MODEL_ID"$'\x1f'"$EFFORT"$'\x1f'"$FIVE_HOUR"$'\x1f'"$SEVEN_DAY"$'\x1f'"$WEEK_PCT"$'\x1f'"$WEEK_MODEL"$'\x1f'"$PERCENT_USED"$'\x1f'"$_rex_chip_cols"
    _rex_chip_old=""
    [ -r "$_rex_chip_file" ] && IFS= read -r _rex_chip_old < "$_rex_chip_file"
    if [ "$_rex_chip_new" != "$_rex_chip_old" ]; then
        [ -d "$_rex_chip_dir" ] || mkdir -p "$_rex_chip_dir"
        # One short write, read back whole by rex-chip; it gets none of the
        # renderer's reader pipes (fds 3-5), so it cannot hold one open.
        if printf '%s\n' "$_rex_chip_new" > "$_rex_chip_file"; then
            ( "$_rex_chip_cmd" sync "$REX_BLOCK" >/dev/null 2>&1 3<&- 4<&- 5<&- & ) 2>/dev/null
        fi
    fi
fi
