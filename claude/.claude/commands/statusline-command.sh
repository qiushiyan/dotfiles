#!/bin/bash
input=$(cat)

# Catppuccin Mocha colors (ANSI 256-color escape codes)
CYAN=$'\033[38;5;111m'      # Blue #89B4FA
GREEN=$'\033[38;5;151m'     # Green #A6E3A1
YELLOW=$'\033[38;5;216m'    # Peach #FAB387
RED=$'\033[38;5;211m'       # Red #F38BA8
PINK=$'\033[38;5;218m'      # Pink #F5C2E7
LAVENDER=$'\033[38;5;147m'  # Lavender #B4BEFE
DIM=$'\033[2m'
RESET=$'\033[0m'

# Single jq call to extract all values
read -r CURRENT_DIR CONTEXT_SIZE CURRENT_TOKENS <<< "$(echo "$input" | jq -r '
  .context_window as $ctx |
  ($ctx.current_usage // {}) as $usage |
  (if $ctx.current_usage != null then
    ($usage.input_tokens // 0) + ($usage.output_tokens // 0) + ($usage.cache_read_input_tokens // 0) + ($usage.cache_creation_input_tokens // 0)
  else
    $ctx.total_input_tokens + $ctx.total_output_tokens
  end) as $tokens |
  "\(.workspace.current_dir) \($ctx.context_window_size) \($tokens)"
')"

# Validate jq extraction succeeded
if [ -z "$CURRENT_DIR" ]; then
    echo "statusline: invalid input" >&2
    exit 1
fi

if [ "$CONTEXT_SIZE" -gt 0 ] 2>/dev/null; then
    PERCENT_USED=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))
else
    PERCENT_USED=0
fi

# Context sparkline - shows usage trajectory
HISTORY_FILE="/tmp/claude_statusline_ctx_history"
BLOCKS="▂▃▄▅▅▆▇█"  # Start at ▂ for better vertical alignment

# Append current reading
echo "$PERCENT_USED" >> "$HISTORY_FILE"

# Keep last 8 readings
tail -8 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" 2>/dev/null && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

# Generate sparkline with colors based on value
SPARKLINE=""
while IFS= read -r pct; do
    if [[ "$pct" =~ ^[0-9]+$ ]]; then
        idx=$((pct * 8 / 101))
        [ $idx -gt 7 ] && idx=7
        bar="${BLOCKS:$idx:1}"
        # Color based on percentage: dim gray < 50, normal 50-74, yellow 75-89, red 90+
        if [ "$pct" -lt 50 ]; then
            SPARKLINE="${SPARKLINE}${DIM}${bar}${RESET}"
        elif [ "$pct" -lt 75 ]; then
            SPARKLINE="${SPARKLINE}${bar}"
        elif [ "$pct" -lt 90 ]; then
            SPARKLINE="${SPARKLINE}${YELLOW}${bar}${RESET}"
        else
            SPARKLINE="${SPARKLINE}${RED}${bar}${RESET}"
        fi
    fi
done < "$HISTORY_FILE"

# Pad with dim empty blocks
while [ ${#SPARKLINE} -lt 8 ]; do
    # Account for color codes in length check - count actual bars
    bar_count=$(echo -e "$SPARKLINE" | sed 's/\x1b\[[0-9;]*m//g' | wc -c)
    bar_count=$((bar_count - 1))  # subtract newline
    [ "$bar_count" -ge 8 ] && break
    SPARKLINE="${DIM}▁${RESET}${SPARKLINE}"
done

# Semantic context display with sparkline
if [ "$PERCENT_USED" -lt 50 ]; then
    CTX_DISPLAY="${GREEN}${PERCENT_USED}%${RESET} ${SPARKLINE}"
elif [ "$PERCENT_USED" -lt 75 ]; then
    CTX_DISPLAY="${YELLOW}${PERCENT_USED}%${RESET} ${SPARKLINE}"
elif [ "$PERCENT_USED" -lt 90 ]; then
    CTX_DISPLAY="${YELLOW}ctx:high ${PERCENT_USED}%${RESET} ${SPARKLINE}"
else
    CTX_DISPLAY="${RED}⚠ ctx:${PERCENT_USED}%${RESET} ${SPARKLINE}"
fi

# API billing indicator
API_INDICATOR=""
if [ -n "$ANTHROPIC_BASE_URL" ]; then
    API_INDICATOR=" | ${YELLOW}API${RESET}"
fi

# Git information - single call for all data
GIT_OUTPUT=$(git -C "$CURRENT_DIR" --no-optional-locks status -b --porcelain 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$GIT_OUTPUT" ]; then
    REPO_NAME="${CURRENT_DIR/#$HOME\/workspace\//}"

    # First line has branch: ## branch...tracking
    BRANCH=$(echo "$GIT_OUTPUT" | head -1 | sed 's/^## \([^.]*\).*/\1/')

    # Rest of lines are file status
    read -r STAGED UNSTAGED UNTRACKED <<< "$(echo "$GIT_OUTPUT" | tail -n +2 | awk '
      BEGIN { s=0; u=0; q=0 }
      /^[MADRC]/ { s++ }
      /^.[MD]/ { u++ }
      /^\?\?/ { q++ }
      END { print s, u, q }
    ')"

    # Build git status string - only show non-zero counts
    GIT_STATUS=""
    [ "$STAGED" -gt 0 ] 2>/dev/null && GIT_STATUS="${GIT_STATUS}${GREEN}+${STAGED}${RESET} "
    [ "$UNSTAGED" -gt 0 ] 2>/dev/null && GIT_STATUS="${GIT_STATUS}${YELLOW}~${UNSTAGED}${RESET} "
    [ "$UNTRACKED" -gt 0 ] 2>/dev/null && GIT_STATUS="${GIT_STATUS}?${UNTRACKED} "
    GIT_STATUS="${GIT_STATUS% }"  # trim trailing space

    if [ -n "$GIT_STATUS" ]; then
        printf "${LAVENDER}%s${RESET} | ${PINK}%s${RESET} | %s | %s%s" \
            "$REPO_NAME" "$BRANCH" "$GIT_STATUS" "$CTX_DISPLAY" "$API_INDICATOR"
    else
        printf "${LAVENDER}%s${RESET} | ${PINK}%s${RESET} | %s%s" \
            "$REPO_NAME" "$BRANCH" "$CTX_DISPLAY" "$API_INDICATOR"
    fi
else
    printf "${LAVENDER}%s${RESET} | %s%s" "$CURRENT_DIR" "$CTX_DISPLAY" "$API_INDICATOR"
fi
