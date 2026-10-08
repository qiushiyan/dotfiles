# shellcheck shell=bash
# statusline-rex.sh — the Claude statusline's Rex half: the context chip's
# values for the chip strip, a two-row pane under the Claude pane that draws
# them in colour (rex/.local/bin/rex-chip; prefix C opens it). The Rex lab's
# counterpart of the tmux border chip (docs/rex.md;
# tmux/.config/tmux/scripts/context-chip.md). Sourced by statusline-command.sh
# after statusline-chip.sh, only inside Rex (REX_BLOCK), reading what the chip
# computed: PERCENT_USED MODEL_ID EFFORT FIVE_HOUR SEVEN_DAY ACCOUNT WEEK_PCT
# WEEK_MODEL. Prints nothing.
#
# One line per Claude block, in ~/.cache/claude-ctx/rex/<block>.chip:
#   ctx account model effort 5h 7d week-pct week-model    ("-" for none)
# rewritten only when a value changed, with builtins only: this runs ~3×/second
# while Claude streams, and the strip redraws when the file's time moves.

rex_chip_dir="$HOME/.cache/claude-ctx/rex"
[ -d "$rex_chip_dir" ] || mkdir -p "$rex_chip_dir" 2>/dev/null
rex_chip_file="$rex_chip_dir/${REX_BLOCK//:/_}.chip"
rex_chip_line="${PERCENT_USED:--} ${ACCOUNT:--} ${MODEL_ID:--} ${EFFORT:--} ${FIVE_HOUR:--} ${SEVEN_DAY:--} ${WEEK_PCT:--} ${WEEK_MODEL:--}"
rex_chip_last=""
[ -r "$rex_chip_file" ] && IFS= read -r rex_chip_last < "$rex_chip_file"
[ "$rex_chip_line" = "$rex_chip_last" ] || printf '%s\n' "$rex_chip_line" > "$rex_chip_file"
