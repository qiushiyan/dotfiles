# shellcheck shell=bash
# statusline-chip.sh — the Claude statusline's tmux half: which account lane
# this session burns, that lane's model-scoped weekly off the refresher's
# cache, the refresher's trigger, and the one compare-and-set that publishes
# the pane chip (tmux/.config/tmux/scripts/context-chip.md). Sourced by
# statusline-command.sh after the payload parse and BEFORE the line is drawn,
# so neither the palette nor the render can keep the chip from publishing.
# Reads PERCENT_USED SESSION_ID MODEL_ID EFFORT FIVE_HOUR SEVEN_DAY; prints
# nothing. It runs in the render's process, ~3×/second per pane while a
# session streams: builtins only, beyond one jq read of ~/.claude.json and the
# one tmux call.

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
# encodes too. That parse costs ~4ms on a ~130KB file, overlapped by the
# render's readers already running, and 1500/1500 reads at render rate came
# back whole — so nothing caches it, and a file that will not parse yields no
# label rather than a guess. It is read on EVERY lane, not just the primary's,
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

# The model-scoped weekly, off the file claude-quota-refresh.sh maintains for
# this lane (that script documents the line's six fields and why they are what
# they are). Everything here obeys one rule: NO SUBPROCESS. `read` with a
# redirect is a builtin, the line is read whole, and every decision below is
# bash arithmetic — this block runs ~3×/second per pane while a session
# streams, and the number it draws changes about half a point an hour.
#
# When to believe an old reading is the whole design. Inside a live window
# usage only climbs, so a stale figure UNDERSTATES and is safe to draw; once
# the window has rolled over the same figure describes a window nobody is
# spending against, and a low number there reads as headroom that may not
# exist. So the reset instant decides, not the age — and age is consulted only
# for the case the vendor leaves the reset null, where nothing else can.
WEEK_PCT=""; WEEK_MODEL=""
NOW="${EPOCHSECONDS:-}"
[ -n "$NOW" ] || NOW=$(date +%s)   # bash < 5 has no EPOCHSECONDS; settings.json
                                   # runs this through PATH bash, which is 5.x
QUOTA_LANE="${LANE_EMAIL//[^a-zA-Z0-9._@-]/}"
QUOTA_FILE="$HOME/.cache/claude-ctx/$QUOTA_LANE.quota"
QUOTA_AT=0
if [ -n "$QUOTA_LANE" ] && [ -r "$QUOTA_FILE" ]; then
    q_at=""; q_lane=""; q_pct=""; q_model=""; q_obs=""; q_res=""
    read -r q_at q_lane q_pct q_model q_obs q_res < "$QUOTA_FILE"
    # A line written for a DIFFERENT lane is not this lane's data and does not
    # count as an attempt either — leaving QUOTA_AT at 0 re-arms the refresh
    # below, which rewrites the file for whoever is asking now.
    if [ "$q_lane" = "$QUOTA_LANE" ]; then
        case "$q_at" in ''|*[!0-9]*) ;; *) QUOTA_AT="$q_at" ;; esac
        live=0
        case "$q_res" in
            ''|*[!0-9]*)
                # No reset instant to judge by: fall back to age, and be
                # conservative about it — half an hour, well past the refresh
                # cadence, so this only ever fires when refreshing is broken.
                case "$q_obs" in
                    ''|*[!0-9]*) ;;
                    *) [ "$((NOW - q_obs))" -le 1800 ] && live=1 ;;
                esac ;;
            *) [ "$q_res" -gt "$NOW" ] && live=1 ;;
        esac
        # An unlabeled number beside 7d:NN could be anything, so the model name
        # is as load-bearing as the percentage; "-" in either field means the
        # refresher had nothing trustworthy and the chip shows nothing.
        if [ "$live" = 1 ] && [ -n "$q_model" ] && [ "$q_model" != "-" ]; then
            case "$q_pct" in
                ''|*[!0-9]*) ;;
                *) WEEK_PCT="$q_pct"; WEEK_MODEL="$q_model" ;;
            esac
        fi
    fi
fi

# Re-arm the refresher when its last ATTEMPT (not its last success) has aged
# out. The refresher stamps its attempt before fetching, so sibling panes stop
# re-arming it within milliseconds; it stays detached so rendering never waits
# for headroom, and it gets none of the renderer's reader pipes (fds 3-5), so
# it cannot hold one open past the render.
# CLAUDE_CTX_REFRESH_CMD is a test lever, not a setting. UNSET (production)
# means the refresher beside this script; set-but-EMPTY turns refreshing off;
# set to a path substitutes that. The chip suite needs all three: it drives
# the statusline for real, so an unlevered spawn would reach past its sandbox
# to the live headroom store and the network — but a suite that only ever
# disabled the spawn would leave the trigger and the throttle below
# permanently untested, which is how they would rot.
QUOTA_REFRESH="${CLAUDE_CTX_REFRESH_CMD-${BASH_SOURCE[0]%/*}/claude-quota-refresh.sh}"
if [ -n "$LANE_EMAIL" ] && [ -n "$QUOTA_REFRESH" ] &&
   [ "$((NOW - QUOTA_AT))" -gt 300 ] && [ -r "$QUOTA_REFRESH" ]; then
    ( bash "$QUOTA_REFRESH" "$LANE_EMAIL" >/dev/null 2>&1 3<&- 4<&- 5<&- & ) 2>/dev/null
fi

# Publish the chip to the tmux pane border. tmux-agent-status.sh owns the
# vocabulary and the gate: sourcing it (a builtin read, no process) yields
# agent_claude_publish, which builds ONE server-side compare-and-set — accept
# only when this session is not tombstoned and some value changed, write every
# field, reconcile the border in the background. Every value gets a gate arm:
# the percentage, MODEL and EFFORT change mid-session (/model, /effort); the
# OWNER lets a successor resuming at its predecessor's exact values record its
# own sid; the ACCOUNT is fixed per session but backfills a pane published
# before the option existed, a normal state in a stowed live repo; and the
# QUOTA values can legitimately go EMPTY (a window rolls over, the refresher
# cannot reach headroom, API billing carries no rate_limits) — empty is a
# value, which is what lets a stale weekly stop being drawn. At steady state no
# arm fires and nothing is written; this runs ~3×/sec while streaming.
# Arguments follow AGENT_CLAUDE_FIELDS (lib/agent-vocab.sh); a count that
# disagrees with the vocabulary publishes nothing rather than misaligned values.
AGENT_STATUS_LIB="$HOME/.config/tmux/scripts/tmux-agent-status.sh"
if [ -n "${TMUX_PANE:-}" ] && [ "${SESSION_ID:--}" != "-" ] && [ -r "$AGENT_STATUS_LIB" ] &&
   . "$AGENT_STATUS_LIB" &&
   agent_claude_publish "$TMUX_PANE" "$PERCENT_USED" "$SESSION_ID" "$MODEL_ID" "$EFFORT" \
       "$ACCOUNT" "$FIVE_HOUR" "$SEVEN_DAY" "$WEEK_PCT" "$WEEK_MODEL"; then
    tmux if-shell -F -t "$TMUX_PANE" "$AGENT_GATE" "$AGENT_PUBLISH" 2>/dev/null || true
fi
