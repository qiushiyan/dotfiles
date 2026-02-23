#!/bin/bash
# copy-plan-to-clipboard.sh
# PostToolUse hook for ExitPlanMode — copies the plan to clipboard
# so you can share it with your engineering team for discussion.

# Find the most recently modified plan file.
# The plan is written to ~/.claude/plans/ right before ExitPlanMode fires,
# so the newest file is the one we want.
PLAN_DIR="$HOME/.claude/plans"
PLAN_FILE=$(ls -t "$PLAN_DIR"/*.md 2>/dev/null | head -1)

if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
  printf '<plan>\n%s\n</plan>' "$(cat "$PLAN_FILE")" | pbcopy
  # Extract plan title from the first heading, stripping the leading "# "
  TITLE=$(head -1 "$PLAN_FILE" | sed 's/^#\+ *//')
  osascript -e "display notification \"Copied to clipboard — ready to share with the team\" with title \"$TITLE\"" 2>/dev/null
  afplay /System/Library/Sounds/Bottle.aiff &
fi
