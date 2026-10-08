#!/bin/bash
#
# Claude Code statusline. One process per render, four files:
#   statusline-command.sh   this file: the payload, then the line itself
#   statusline-chip.sh      the tmux pane chip, published before the line is
#                           drawn so nothing below can stop it
#   statusline-rex.sh       inside Rex, the same chip as the terminal title
#   statusline-palette.sh   the colours, one arm per theme (docs/theming.md)
# The others are sourced, not run: a fork here costs every pane on every
# render.

case "${BASH_SOURCE[0]}" in
    */*) STATUSLINE_DIR="${BASH_SOURCE[0]%/*}" ;;
    *)   STATUSLINE_DIR=. ;;   # run as `bash statusline-command.sh` from its dir
esac

IFS= read -r -d '' input

# Single jq call to extract all values. The directory comes LAST: read splits
# on whitespace and only the final variable swallows the remainder, so a path
# with spaces survives intact (dir-first shifted the numbers and corrupted the
# percentage). session_id (a uuid, no spaces) identifies this Claude session
# to the tmux chip's tombstone check (statusline-chip.sh).
#
# model.id reaches the tmux chip near-verbatim: the only edit is dropping the
# "claude-" vendor prefix every id carries, which is width on a pane border and
# says nothing ("claude-opus-5[1m]" → "opus-5[1m]"). No other prettifying — the
# family, the version and the "[1m]" 1M-context tag are the raw id's.
# jq strips everything outside [A-Za-z0-9._[]-] first, which does two jobs at
# once: it guarantees a single whitespace-free token (so the read above keeps
# its field alignment) and it keeps quotes, commas and braces — which would
# break the tmux format string and the chip's single-quoted set-option — out of
# a value that travels into both. Absent/empty yields "-" only to hold the
# field's place for read; the lines below turn it back into the empty string,
# so the border format needs ONE presence test (a length check) rather than a
# length check plus a sentinel comparison.
#
# effort.level is the reasoning effort in force ("high", "xhigh"), present only
# while the model takes one. It gets the model id's scrub and the same "-"
# placeholder, and the border draws it as a suffix of the model
# ("opus-5[1m]:high"), never as a field of its own.
#
# rate_limits.five_hour and rate_limits.seven_day are the vendor's own figures
# for the account THIS session burns — live, exact, and already in hand, so the
# chip's two account-wide numbers cost nothing beyond these fields. seven_day
# is the ALL-MODELS weekly. The model-scoped weekly, which the payload does not
# carry at all, comes from headroom, off the cache file statusline-chip.sh reads.
# Either window may be absent on its own (the vendor drops one once it resets).
# used_percentage is documented as a float and observed as an integer, so it is
# rounded; a value that survives that and still is not a plain integer is
# treated as absent below rather than pushed at a tmux format.
#
# prompt_cache.expires_at is when the main conversation's cached prefix leaves
# its TTL (1h here), in epoch seconds; every request that reads the cache moves
# it. jq's `now` turns it into seconds left, so bash 3.2 (no $EPOCHSECONDS)
# needs no `date` fork. A cache that is not warm, or whose expiry has passed
# before Claude Code re-rendered, is 0: cold. No expiry at all (no request yet,
# or a provider that reports no cache tokens) is "-", and draws nothing.
read -r CONTEXT_SIZE CURRENT_TOKENS SESSION_ID MODEL_ID EFFORT FIVE_HOUR SEVEN_DAY CACHE_LEFT CURRENT_DIR <<< "$(echo "$input" | jq -r '
  def pct: if . == null then "-" else (round | tostring) end;
  def token: if . == "" then "-" else . end;
  .context_window as $ctx |
  ($ctx.current_usage // {}) as $usage |
  (if $ctx.current_usage != null then
    ($usage.input_tokens // 0) + ($usage.output_tokens // 0) + ($usage.cache_read_input_tokens // 0) + ($usage.cache_creation_input_tokens // 0)
  else
    $ctx.total_input_tokens + $ctx.total_output_tokens
  end) as $tokens |
  ((.model.id // "") | gsub("[^a-zA-Z0-9._\\[\\]-]"; "")) as $model |
  ((.effort.level? // "") | tostring | gsub("[^a-zA-Z0-9._-]"; "")) as $effort |
  ((.rate_limits.five_hour.used_percentage // null) | pct) as $five |
  ((.rate_limits.seven_day.used_percentage // null) | pct) as $seven |
  ((.prompt_cache // {}) as $pc |
    if ($pc.expires_at | type) != "number" then "-"
    elif $pc.warm == false then "0"
    else [($pc.expires_at - now) | floor, 0] | max | tostring end) as $cache |
  "\($ctx.context_window_size) \($tokens) \(.session_id // "-") \($model | token) \($effort | token) \($five) \($seven) \($cache) \(.workspace.current_dir)"
')"
[ "$MODEL_ID" = "-" ] && MODEL_ID=""
MODEL_ID="${MODEL_ID#claude-}"
[ "$EFFORT" = "-" ] && EFFORT=""
case "$FIVE_HOUR" in
    ''|*[!0-9]*) FIVE_HOUR="" ;;
esac
case "$SEVEN_DAY" in
    ''|*[!0-9]*) SEVEN_DAY="" ;;
esac

# Validate jq extraction succeeded
if [ -z "$CURRENT_DIR" ]; then
    echo "statusline: invalid input" >&2
    exit 1
fi

# The render's three git readers start now, side by side, so their ~16 ms
# overlaps the chip's work below instead of following it. The display path
# reads fd 3; the branch and counts read fds 4 and 5.
exec 3< <(git -C "$CURRENT_DIR" rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel 2>/dev/null)
exec 4< <(git -C "$CURRENT_DIR" --no-optional-locks status -b --porcelain 2>/dev/null)
exec 5< <(git -C "$CURRENT_DIR" --no-optional-locks diff HEAD --numstat 2>/dev/null)

if [ "$CONTEXT_SIZE" -gt 0 ] 2>/dev/null; then
    PERCENT_USED=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))
else
    PERCENT_USED=0
fi

. "$STATUSLINE_DIR/statusline-chip.sh"
[ -n "${REX_BLOCK:-}" ] && . "$STATUSLINE_DIR/statusline-rex.sh"

# Resolve the active theme FILE-FIRST (not env-first): the file is the live
# source of truth that `theme-set` rewrites, so an already-running Claude session
# — which inherited a now-stale $TERMINAL_THEME from its launching shell — still
# tracks theme switches on the next statusline render. Env is only the fallback.
THEME=""
[ -r "$HOME/.config/terminal-theme" ] && read -r THEME < "$HOME/.config/terminal-theme"
THEME="${THEME:-${TERMINAL_THEME:-gruber_darker}}"

# A theme with no arm in the palette (a port that never reached it) draws in
# the default's colours and says so on stderr, rather than drawing nothing.
if ! . "$STATUSLINE_DIR/statusline-palette.sh"; then
    echo "statusline: unknown theme '$THEME'" >&2
    THEME=gruber_darker
    . "$STATUSLINE_DIR/statusline-palette.sh"
fi
RESET=$'\033[0m'

# Display path: the convention the Codex pane border shares, defined once in
# lib/display-path.sh (a linked worktree shows its main checkout, ~/dev is
# implicit, the rest of home is ~). Here a linked worktree also wears
# nf-fa-clone (U+F24D), the "linked copy" glyph at full cell size; every
# configured terminal font is a Nerd Font. It is spelled as UTF-8 bytes
# because an editor once saved the literal private-use character as nothing.
GIT_DIR=""; GIT_COMMON=""; TOPLEVEL=""
{ read -r GIT_DIR; read -r GIT_COMMON; read -r TOPLEVEL; } <&3; exec 3<&-
DISPLAY_PATH="$CURRENT_DIR"; DISPLAY_PATH_LINKED=""   # the raw path, without the tmux package
. "$HOME/.config/tmux/scripts/lib/display-path.sh" 2>/dev/null &&
    display_path "$CURRENT_DIR" "$HOME" "$GIT_DIR" "$GIT_COMMON" "$TOPLEVEL"
DISPLAY_DIR="$DISPLAY_PATH"
[ -n "$DISPLAY_PATH_LINKED" ] && DISPLAY_DIR=$'\xef\x89\x8d '"$DISPLAY_PATH"

# Semantic context display — numeric percentage, colored by severity.
# CTX_PLAIN mirrors the visible text (no ANSI) so we can measure width for wrapping.
if [ "$PERCENT_USED" -lt 50 ]; then
    CTX_DISPLAY="${GREEN}${PERCENT_USED}%${RESET}"; CTX_PLAIN="${PERCENT_USED}%"
elif [ "$PERCENT_USED" -lt 75 ]; then
    CTX_DISPLAY="${YELLOW}${PERCENT_USED}%${RESET}"; CTX_PLAIN="${PERCENT_USED}%"
elif [ "$PERCENT_USED" -lt 90 ]; then
    CTX_DISPLAY="${YELLOW}ctx:high ${PERCENT_USED}%${RESET}"; CTX_PLAIN="ctx:high ${PERCENT_USED}%"
else
    CTX_DISPLAY="${RED}⚠ ctx:${PERCENT_USED}%${RESET}"; CTX_PLAIN="⚠ ctx:${PERCENT_USED}%"
fi

# Prompt cache countdown: whole minutes left, rounded up, so "1m" is the last
# minute and the next render after expiry says cold. Claude Code re-renders at
# expires_at on its own; settings.json's refreshInterval moves the minutes in
# between while the session sits idle.
CACHE_DISPLAY=""; CACHE_PLAIN=""
case "$CACHE_LEFT" in
    ''|*[!0-9]*) ;;
    0) CACHE_PLAIN="cache cold"; CACHE_DISPLAY="${RED}${CACHE_PLAIN}${RESET}" ;;
    *)
        CACHE_MIN=$(( (CACHE_LEFT + 59) / 60 ))
        CACHE_PLAIN="cache ${CACHE_MIN}m"
        if [ "$CACHE_MIN" -gt 10 ]; then
            CACHE_DISPLAY="${CYAN}${CACHE_PLAIN}${RESET}"
        else
            CACHE_DISPLAY="${YELLOW}${CACHE_PLAIN}${RESET}"
        fi
        ;;
esac

# API billing indicator
API_DISPLAY=""; API_PLAIN=""
if [ -n "$ANTHROPIC_BASE_URL" ]; then
    API_DISPLAY="${YELLOW}API${RESET}"; API_PLAIN="API"
fi

# Branch and counts, off the readers started above. The branch is
# the porcelain header minus "## " and any "...upstream" suffix (git forbids
# ".." in a ref, so "..." is unambiguous; a dotted branch like release-1.2
# survives). `git diff HEAD --numstat` walks tracked files once and covers
# staged AND unstaged changes without double-counting a file touched in both.
# Untracked files carry no diff against HEAD and stay the separate "?N" count.
BRANCH=""; GIT_STATUS=""; GIT_PLAIN=""
STAGED=0; UNTRACKED=0; DIFF_ADDED=0; DIFF_REMOVED=0
if IFS= read -r line <&4; then
    BRANCH=${line#'## '}; BRANCH=${BRANCH%%...*}
    BRANCH=${BRANCH#No commits yet on }
    while IFS= read -r line; do
        case "$line" in [MADRC]*) STAGED=$((STAGED+1)) ;; '??'*) UNTRACKED=$((UNTRACKED+1)) ;; esac
    done <&4
    while read -r a d _; do
        case "$a" in ''|*[!0-9]*) ;; *) DIFF_ADDED=$((DIFF_ADDED+a)) ;; esac
        case "$d" in ''|*[!0-9]*) ;; *) DIFF_REMOVED=$((DIFF_REMOVED+d)) ;; esac
    done <&5
    [ "$STAGED" -gt 0 ] && { GIT_STATUS="${GIT_STATUS}${GREEN}+${STAGED}${RESET} "; GIT_PLAIN="${GIT_PLAIN}+${STAGED} "; }
    if [ "$DIFF_ADDED" -gt 0 ] || [ "$DIFF_REMOVED" -gt 0 ]; then
        GIT_STATUS="${GIT_STATUS}${GREEN}+${DIFF_ADDED}${RESET} ${RED}-${DIFF_REMOVED}${RESET} "
        GIT_PLAIN="${GIT_PLAIN}+${DIFF_ADDED} -${DIFF_REMOVED} "
    fi
    [ "$UNTRACKED" -gt 0 ] && { GIT_STATUS="${GIT_STATUS}?${UNTRACKED} "; GIT_PLAIN="${GIT_PLAIN}?${UNTRACKED} "; }
    GIT_STATUS="${GIT_STATUS% }"; GIT_PLAIN="${GIT_PLAIN% }"
fi
exec 4<&- 5<&-

# Assemble the line as ordered segments, each carrying its colored form and its
# plain (visible) text. render_segments decides between one line and wrapping.
SEG_COLORED=(); SEG_PLAIN=()
add_seg() { [ -n "$2" ] && { SEG_COLORED+=("$1"); SEG_PLAIN+=("$2"); }; }

add_seg "${LAVENDER}${DISPLAY_DIR}${RESET}" "$DISPLAY_DIR"
add_seg "${PINK}${BRANCH}${RESET}" "$BRANCH"
add_seg "$CTX_DISPLAY" "$CTX_PLAIN"
add_seg "$CACHE_DISPLAY" "$CACHE_PLAIN"
add_seg "$GIT_STATUS" "$GIT_PLAIN"
add_seg "$API_DISPLAY" "$API_PLAIN"

# Greedy-wrap segments to the pane width. Claude Code sets $COLUMNS to the
# terminal/pane width before invoking us (v2.1.153+); when it's absent or the
# whole line fits, we emit a single row identical to the pre-wrap behavior. A
# lone segment wider than the pane still overflows — accepted, not fought.
SEP=" | "; SEPLEN=3
COLS="${COLUMNS:-0}"
n=${#SEG_PLAIN[@]}

total=0
for ((i=0; i<n; i++)); do total=$(( total + ${#SEG_PLAIN[i]} )); done
[ "$n" -gt 0 ] && total=$(( total + (n-1)*SEPLEN ))

if [ "$COLS" -le 0 ] || [ "$total" -le "$COLS" ]; then
    out=""
    for ((i=0; i<n; i++)); do
        [ "$i" -gt 0 ] && out="${out}${SEP}"
        out="${out}${SEG_COLORED[i]}"
    done
    printf '%s' "$out"
else
    out=""; line=""; linelen=0
    for ((i=0; i<n; i++)); do
        seglen=${#SEG_PLAIN[i]}
        if [ -z "$line" ]; then
            line="${SEG_COLORED[i]}"; linelen=$seglen
        elif [ $(( linelen + SEPLEN + seglen )) -le "$COLS" ]; then
            line="${line}${SEP}${SEG_COLORED[i]}"; linelen=$(( linelen + SEPLEN + seglen ))
        else
            out="${out}${line}"$'\n'; line="${SEG_COLORED[i]}"; linelen=$seglen
        fi
    done
    printf '%s' "${out}${line}"
fi
