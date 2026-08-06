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
    tokyo_night_moon)
        # Dark bg (#222436) — Tokyo Night Moon's bright accents read well on it
        CYAN=$'\033[38;2;134;225;252m'      # Cyan #86e1fc
        GREEN=$'\033[38;2;195;232;141m'     # Green #c3e88d
        YELLOW=$'\033[38;2;255;199;119m'    # Yellow #ffc777
        RED=$'\033[38;2;255;117;127m'       # Red #ff757f
        PINK=$'\033[38;2;192;153;255m'      # Magenta #c099ff
        LAVENDER=$'\033[38;2;130;170;255m'  # Blue #82aaff
        ;;
    gruvbox_dark)
        # Dark bg (#282828) — gruvbox's bright accents read well on it
        CYAN=$'\033[38;2;142;192;124m'      # Aqua #8ec07c
        GREEN=$'\033[38;2;184;187;38m'      # Green #b8bb26
        YELLOW=$'\033[38;2;250;189;47m'     # Yellow #fabd2f
        RED=$'\033[38;2;251;73;52m'         # Red #fb4934
        PINK=$'\033[38;2;211;134;155m'      # Purple #d3869b
        LAVENDER=$'\033[38;2;131;165;152m'  # Blue #83a598
        ;;
    *)
        echo "statusline: unknown theme '$THEME'" >&2
        exit 1
        ;;
esac
DIM=$'\033[2m'
RESET=$'\033[0m'

input=$(cat)

# Single jq call to extract all values. The directory comes LAST: read splits
# on whitespace and only the final variable swallows the remainder, so a path
# with spaces survives intact (dir-first shifted the numbers and corrupted the
# percentage). session_id (a uuid, no spaces) identifies this Claude session
# to the tmux chip's tombstone check below.
#
# model.id reaches the tmux chip near-verbatim: the only edit is dropping the
# "claude-" vendor prefix every id carries, which is width on a pane border and
# says nothing ("claude-opus-5[1m]" → "opus-5[1m]"). No other prettifying — the
# family, the version and the "[1m]" 1M-context tag are the raw id's.
# jq strips everything outside [A-Za-z0-9._[]-] first, which does two jobs at
# once: it guarantees a single whitespace-free token (so the read above keeps
# its field alignment) and it keeps quotes, commas and braces — which would
# break the tmux format string and the single-quoted set-option below — out of
# a value that travels into both. Absent/empty yields "-" only to hold the
# field's place for read; the lines below turn it back into the empty string,
# so the border format needs ONE presence test (a length check) rather than a
# length check plus a sentinel comparison.
read -r CONTEXT_SIZE CURRENT_TOKENS SESSION_ID MODEL_ID CURRENT_DIR <<< "$(echo "$input" | jq -r '
  .context_window as $ctx |
  ($ctx.current_usage // {}) as $usage |
  (if $ctx.current_usage != null then
    ($usage.input_tokens // 0) + ($usage.output_tokens // 0) + ($usage.cache_read_input_tokens // 0) + ($usage.cache_creation_input_tokens // 0)
  else
    $ctx.total_input_tokens + $ctx.total_output_tokens
  end) as $tokens |
  ((.model.id // "") | gsub("[^a-zA-Z0-9._\\[\\]-]"; "")) as $model |
  "\($ctx.context_window_size) \($tokens) \(.session_id // "-") \(if $model == "" then "-" else $model end) \(.workspace.current_dir)"
')"
[ "$MODEL_ID" = "-" ] && MODEL_ID=""
MODEL_ID="${MODEL_ID#claude-}"

# Which account lane this session burns. EVERY lane is labeled, the primary
# included: "which account is this session spending" is the same question
# whether or not that account happens to be the default one, so the border
# answers it the same way. (It did not always. The primary was once the
# deliberately unmarked lane — zero border width spent on the common case —
# which in practice read as a chip that was broken for the account that runs
# most, and made the label's absence carry meaning nobody recovers unaided.)
#
# The email comes from one of two places, because the vendor leaves the primary
# no dir name to read. headroom launches an extra with
# CLAUDE_CONFIG_DIR=~/.claude-accounts/<email>, so the dir name IS the email —
# and it is the lane identity headroom actually routed to, free of any file
# read. The primary launches with that variable ABSENT (headroom's contract,
# docs/claude-accounts.md) and keeps its login in ~/.claude.json — directly in
# $HOME, NOT inside ~/.claude, the vendor layout headroom's PrimaryMeta()
# encodes too. That parse costs ~4ms on a ~130KB file, against the two `git`
# calls this render already makes, and 1500/1500 reads at render rate came back
# whole — so nothing caches it, and a file that will not parse yields no label
# rather than a guess. It is read on EVERY lane, not just the primary's,
# because the primary's local part is part of the registry the uniqueness rule
# below counts against.
#
# A CLAUDE_CONFIG_DIR pointing anywhere else is the unmanaged escape hatch
# (docs/claude-accounts.md) and wears its own dir's basename. Whatever that
# session is, it is emphatically not the primary, and quietly lending it the
# primary's email is the one answer here that would actively mislead.
#
# The label is the email's local part while that is UNIQUE across the whole
# registry — the primary AND every account dir — and the full email when two
# lanes claim the same one: claude.zsh's short-alias policy, followed from the
# same registry (the dirs, plus the one account that has no dir), because two
# lanes wearing one label defeats the point of labeling lanes. Everything is
# scrubbed to the model id's inert charset plus "@" (harmless in both hostile
# paths — tmux formats only ever trip on # , { } and quotes) because it rides
# the same two: the tmux format string and the quoted set-option. Uniqueness
# is judged on the DISPLAYED (scrubbed) form, not the raw dir name: the scrub
# deletes legal email chars like "+", so alex+work@… and alexwork@… are
# distinct on disk but identical on the border — labels stay unique up to
# emails that differ only by scrubbed characters.
PRIMARY_EMAIL=""
[ -r "$HOME/.claude.json" ] &&
    PRIMARY_EMAIL=$(jq -r '.oauthAccount.emailAddress // ""' "$HOME/.claude.json" 2>/dev/null)

case "${CLAUDE_CONFIG_DIR:-}" in
    ""|"$HOME/.claude"|"$HOME/.claude/")
        LANE_EMAIL="$PRIMARY_EMAIL" ;;
    *)
        LANE_EMAIL="${CLAUDE_CONFIG_DIR%/}"; LANE_EMAIL="${LANE_EMAIL##*/}" ;;
esac
LANE_LOCAL="${LANE_EMAIL%%@*}"; LANE_LOCAL="${LANE_LOCAL//[^a-zA-Z0-9._-]/}"

# The registry uniqueness is counted against. Membership is tested by walking
# it rather than matching against "${ACCT_REG[*]}" as one string: a dir name is
# attacker-shaped and may contain spaces, which would make a substring test
# find neighbours that aren't there.
ACCT_REG=("$PRIMARY_EMAIL")
for _acct_dir in "$HOME/.claude-accounts"/*/; do
    [ -d "$_acct_dir" ] || continue          # the glob itself, when the root is absent
    _acct_base="${_acct_dir%/}"; ACCT_REG+=("${_acct_base##*/}")
done
_lane_known=0
for _acct_entry in "${ACCT_REG[@]}"; do
    [ "$_acct_entry" = "$LANE_EMAIL" ] && _lane_known=1
done
# An unmanaged dir is in no registry but still must not silently wear a label a
# managed lane already owns.
[ "$_lane_known" -eq 1 ] || ACCT_REG+=("$LANE_EMAIL")

ACCT_CLAIMS=0
for _acct_entry in "${ACCT_REG[@]}"; do
    _acct_base="${_acct_entry%%@*}"; _acct_base="${_acct_base//[^a-zA-Z0-9._-]/}"
    # The empty entry a missing/unparsed ~/.claude.json leaves behind claims
    # nothing — otherwise it would collide with every other empty and push a
    # real lane to its full email for no reason.
    [ -n "$_acct_base" ] && [ "$_acct_base" = "$LANE_LOCAL" ] && ACCT_CLAIMS=$((ACCT_CLAIMS+1))
done

ACCOUNT=""
if [ -n "$LANE_LOCAL" ]; then
    if [ "$ACCT_CLAIMS" -le 1 ]; then
        ACCOUNT="$LANE_LOCAL"
    else
        ACCOUNT="${LANE_EMAIL//[^a-zA-Z0-9._@-]/}"
    fi
fi

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

# Display path. Linked worktrees (gwt / prefix-W put them at
# ~/dev/.worktrees/<repo>/<branch>) render as " <main-checkout>": the raw path's
# grouping key is the main checkout's basename (often an unhelpful "main"), and
# its last segment is the branch — which the branch segment already shows, so the
# full path would say it twice. Detection is git-common-dir, not path parsing, so
# branches with slashes (feat/x → nested dirs) and worktrees made outside the
# convention still resolve. Then: paths under ~/dev show relative to it; other
# paths under $HOME abbreviate to ~/...; everything else stays as-is.
DISPLAY_DIR="$CURRENT_DIR"
WT_MARK=""
GIT_DIRS=$(git -C "$CURRENT_DIR" rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel 2>/dev/null)
if [ -n "$GIT_DIRS" ]; then
    { read -r GIT_DIR; read -r GIT_COMMON; read -r TOPLEVEL; } <<< "$GIT_DIRS"
    if [ -n "$GIT_COMMON" ] && [ -n "$TOPLEVEL" ] && [ "$GIT_DIR" != "$GIT_COMMON" ]; then
        # Keep any subpath below the worktree root so deeper cwds stay visible.
        DISPLAY_DIR="${GIT_COMMON%/.git}${CURRENT_DIR#$TOPLEVEL}"
        # nf-fa-clone (U+F24D): same "linked copy" glyph as ⧉ but drawn at full
        # cell size — needs a Nerd Font, which every configured terminal font is.
        WT_MARK=" "
    fi
fi
DISPLAY_DIR="${DISPLAY_DIR/#$HOME\/dev\//}"
[[ "$DISPLAY_DIR" == "$HOME"* ]] && DISPLAY_DIR="~${DISPLAY_DIR#$HOME}"
DISPLAY_DIR="${WT_MARK}${DISPLAY_DIR}"

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

# API billing indicator
API_DISPLAY=""; API_PLAIN=""
if [ -n "$ANTHROPIC_BASE_URL" ]; then
    API_DISPLAY="${YELLOW}API${RESET}"; API_PLAIN="API"
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

    # Build git status string - only show non-zero counts. GIT_PLAIN mirrors the
    # visible text (no ANSI) so the wrapper can measure its width.
    GIT_STATUS=""; GIT_PLAIN=""
    [ "$STAGED" -gt 0 ] 2>/dev/null && { GIT_STATUS="${GIT_STATUS}${GREEN}+${STAGED}${RESET} "; GIT_PLAIN="${GIT_PLAIN}+${STAGED} "; }
    [ "$UNSTAGED" -gt 0 ] 2>/dev/null && { GIT_STATUS="${GIT_STATUS}${YELLOW}~${UNSTAGED}${RESET} "; GIT_PLAIN="${GIT_PLAIN}~${UNSTAGED} "; }
    [ "$UNTRACKED" -gt 0 ] 2>/dev/null && { GIT_STATUS="${GIT_STATUS}?${UNTRACKED} "; GIT_PLAIN="${GIT_PLAIN}?${UNTRACKED} "; }
    GIT_STATUS="${GIT_STATUS% }"; GIT_PLAIN="${GIT_PLAIN% }"  # trim trailing space
fi

# Assemble the line as ordered segments, each carrying its colored form and its
# plain (visible) text. render_segments decides between one line and wrapping.
SEG_COLORED=(); SEG_PLAIN=()
add_seg() { [ -n "$2" ] && { SEG_COLORED+=("$1"); SEG_PLAIN+=("$2"); }; }

add_seg "${LAVENDER}${DISPLAY_DIR}${RESET}" "$DISPLAY_DIR"
add_seg "${PINK}${BRANCH}${RESET}" "$BRANCH"
add_seg "$CTX_DISPLAY" "$CTX_PLAIN"
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

# Push the percentage, model id and account lane to the tmux pane border (the @claude_ctx
# chip; drawing, ownership, and teardown live in tmux.conf +
# tmux-claude-ctx.sh). One tmux round-trip per render, with the whole gate
# SERVER-side: publish only when the tombstone isn't ours (a statusline
# subprocess can outlive a killed Claude — a tombstoned session id must not
# resurrect the chip it just had cleaned up; the barrier holds until the id
# legitimately starts again, since resume KEEPS the session id — SessionStart
# discharges it via tmux-claude-ctx.sh activate-session) AND something
# actually changed —
# the integer, the MODEL (/model switches mid-session, so it can't be written
# once and forgotten), or the OWNER: a successor session resuming at its
# predecessor's exact percentage must still record its own sid, or the
# predecessor's late cleanup would pass its owner check and erase the
# successor's chip. The ACCOUNT gets a gate arm like the rest even though it
# is fixed for the life of a session (headroom sets the env once, at launch):
# a pane published by a PRE-account version of this script is a normal state
# in a stowed live repo, and with the other three unchanged only an account
# arm backfills it — the arm also self-heals a tampered option and keeps the
# gate honest on its own terms instead of leaning on "resume mints a new
# session id" staying true of the vendor. At steady state the arm never
# fires, so an unchanged quadruple still writes nothing (set-option triggers
# redraw/layout work even for an unchanged value, and this runs ~3×/sec while
# streaming). Every accepted write records all three and reconciles the
# window's border in the background — accepted writes are sparse, and the
# reconcile doubles as passive repair after pane relocation.
if [ -n "${TMUX_PANE:-}" ] && [ "${SESSION_ID:--}" != "-" ]; then
    tmux if-shell -F -t "$TMUX_PANE" \
        "#{&&:#{!=:#{@claude_ctx_dead},$SESSION_ID},#{||:#{!=:#{@claude_ctx},$PERCENT_USED},#{||:#{!=:#{@claude_ctx_sid},$SESSION_ID},#{||:#{!=:#{@claude_ctx_model},$MODEL_ID},#{!=:#{@claude_ctx_account},$ACCOUNT}}}}}" \
        "set-option -p -t '$TMUX_PANE' @claude_ctx '$PERCENT_USED' ; set-option -p -t '$TMUX_PANE' @claude_ctx_sid '$SESSION_ID' ; set-option -p -t '$TMUX_PANE' @claude_ctx_model '$MODEL_ID' ; set-option -p -t '$TMUX_PANE' @claude_ctx_account '$ACCOUNT' ; run-shell -b 'bash $HOME/.config/tmux/scripts/tmux-claude-ctx.sh reconcile $TMUX_PANE'" \
        2>/dev/null || true
fi
