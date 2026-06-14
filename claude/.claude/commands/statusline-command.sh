#!/bin/bash
#
# Claude Code statusline renderer.
#
# Theming: colors come from a per-theme `case` arm below — six truecolor slots
# (CYAN/GREEN/YELLOW/RED/PINK/LAVENDER) chosen for contrast against that theme's
# background, so the render code stays theme-agnostic. See docs/theming.md for
# the cross-tool system and how to add a theme.

# Resolve the active theme FILE-FIRST (not env-first): the file is the live
# source of truth that `theme-set` rewrites, so an already-running Claude session
# — which inherited a now-stale $TERMINAL_THEME from its launching shell — still
# tracks theme switches on the next statusline render. Env is only the fallback.
THEME=""
if [ -r "$HOME/.config/terminal-theme" ]; then
    THEME=$(tr -d '[:space:]' < "$HOME/.config/terminal-theme")
fi
THEME="${THEME:-${TERMINAL_THEME:-flexoki_light}}"

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
    tailwind_light)
        # Light white bg (#ffffff) — Tailwind's darker (non-bright) accents for contrast
        CYAN=$'\033[38;2;0;146;184m'        # Cyan #0092b8
        GREEN=$'\033[38;2;0;153;102m'       # Green #009966
        YELLOW=$'\033[38;2;225;113;0m'      # Amber #e17100
        RED=$'\033[38;2;199;0;54m'          # Red #c70036
        PINK=$'\033[38;2;152;16;250m'       # Purple #9810fa
        LAVENDER=$'\033[38;2;20;71;230m'    # Blue #1447e6
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

# Display path: workspace projects show as bare repo name; other paths
# under $HOME abbreviate to ~/...; everything else stays as-is.
DISPLAY_DIR="${CURRENT_DIR/#$HOME\/workspace\//}"
[[ "$DISPLAY_DIR" == "$HOME"* ]] && DISPLAY_DIR="~${DISPLAY_DIR#$HOME}"

# Semantic context display — numeric percentage, colored by severity
if [ "$PERCENT_USED" -lt 50 ]; then
    CTX_DISPLAY="${GREEN}${PERCENT_USED}%${RESET}"
elif [ "$PERCENT_USED" -lt 75 ]; then
    CTX_DISPLAY="${YELLOW}${PERCENT_USED}%${RESET}"
elif [ "$PERCENT_USED" -lt 90 ]; then
    CTX_DISPLAY="${YELLOW}ctx:high ${PERCENT_USED}%${RESET}"
else
    CTX_DISPLAY="${RED}⚠ ctx:${PERCENT_USED}%${RESET}"
fi

# API billing indicator
API_INDICATOR=""
if [ -n "$ANTHROPIC_BASE_URL" ]; then
    API_INDICATOR=" | ${YELLOW}API${RESET}"
fi

# Git information - single call for all data
GIT_OUTPUT=$(git -C "$CURRENT_DIR" --no-optional-locks status -b --porcelain 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$GIT_OUTPUT" ]; then
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
            "$DISPLAY_DIR" "$BRANCH" "$CTX_DISPLAY" "$GIT_STATUS" "$API_INDICATOR"
    else
        printf "${LAVENDER}%s${RESET} | ${PINK}%s${RESET} | %s%s" \
            "$DISPLAY_DIR" "$BRANCH" "$CTX_DISPLAY" "$API_INDICATOR"
    fi
else
    printf "${LAVENDER}%s${RESET} | %s%s" "$DISPLAY_DIR" "$CTX_DISPLAY" "$API_INDICATOR"
fi
