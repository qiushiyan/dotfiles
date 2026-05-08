#!/bin/bash
#
# Claude Code statusline renderer.
#
# Theming
# -------
# Colors track the shared $TERMINAL_THEME (also drives Oh My Posh prompt and
# zsh ls/completion colors — see zsh/.config/zsh/theme.zsh). Resolution order:
#   1. $TERMINAL_THEME env var
#   2. ~/.config/terminal-theme  (single line, e.g. `flexoki_light`)
#   3. built-in default (flexoki_light)
#
# Supported themes are the `case` arms below: catppuccin_mocha, flexoki_light.
# Each theme defines the same six color slots (CYAN, GREEN, YELLOW, RED, PINK,
# LAVENDER) as 24-bit truecolor escapes, so the rendering code stays
# theme-agnostic. To add a theme, add a new arm; to switch, write the theme
# name into ~/.config/terminal-theme or export the env var.
#
# Light vs dark backgrounds: pick palette entries with enough contrast against
# the terminal bg. Flexoki Light uses the dark palette (0-7) on its cream bg;
# Catppuccin Mocha uses the light/bright palette on its dark bg.

THEME="${TERMINAL_THEME:-}"
if [ -z "$THEME" ] && [ -r "$HOME/.config/terminal-theme" ]; then
    THEME=$(tr -d '[:space:]' < "$HOME/.config/terminal-theme")
fi
THEME="${THEME:-flexoki_light}"

# 24-bit truecolor escape: $'\033[38;2;R;G;Bm'
case "$THEME" in
    catppuccin_mocha)
        CYAN=$'\033[38;2;137;180;250m'      # Blue #89B4FA
        GREEN=$'\033[38;2;166;227;161m'     # Green #A6E3A1
        YELLOW=$'\033[38;2;250;179;135m'    # Peach #FAB387
        RED=$'\033[38;2;243;139;168m'       # Red #F38BA8
        PINK=$'\033[38;2;245;194;231m'      # Pink #F5C2E7
        LAVENDER=$'\033[38;2;180;190;254m'  # Lavender #B4BEFE
        ;;
    flexoki_light)
        # Light cream bg (#fffcf0) needs the darker palette entries (0-7) for contrast
        CYAN=$'\033[38;2;36;131;123m'       # Cyan #24837b
        GREEN=$'\033[38;2;102;128;11m'      # Green #66800b
        YELLOW=$'\033[38;2;173;131;1m'      # Yellow #ad8301
        RED=$'\033[38;2;175;48;41m'         # Red #af3029
        PINK=$'\033[38;2;160;47;111m'       # Magenta #a02f6f
        LAVENDER=$'\033[38;2;32;94;166m'    # Blue #205ea6
        ;;
    *)
        echo "statusline: unknown theme '$THEME'" >&2
        exit 1
        ;;
esac
DIM=$'\033[2m'
RESET=$'\033[0m'

input=$(cat)

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
