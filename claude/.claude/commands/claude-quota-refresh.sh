#!/usr/bin/env bash
# claude-quota-refresh.sh — keep one account lane's model-scoped weekly quota
# on disk for the tmux Claude chip. Spawned detached by statusline-command.sh;
# never on its render path.
#
# Why a file at all. The chip's other fields come free with the render — the
# context %, the model and the account lane are all in the payload Claude Code
# hands the statusline, or in a path it already parsed. The model-scoped weekly
# ("Fable (7d)", routinely the limit that actually stops work while the
# all-models figure sits far lower) is in neither: Claude Code's payload
# carries only `rate_limits.seven_day`, which is the ALL-MODELS weekly. The one
# reachable source is headroom, and headroom's fetching surfaces cost ~300ms
# and spend a request against a per-account budget of roughly one a minute.
# A statusline renders ~3×/second, per pane. So the render reads a file, and
# this script is what puts something in it.
#
# The file — $HOME/.cache/claude-ctx/<lane>.quota — is ONE line of six
# whitespace-separated tokens, so the reader is a single bash `read` with no
# subprocess at all:
#
#   <attempted> <lane> <percent> <model> <observed> <resets>
#
#   attempted  when this script last RAN, written whether or not it learned
#              anything. It is the reader's throttle, and it has to be the
#              attempt rather than the observation: a lane headroom cannot
#              answer for (an unmanaged CLAUDE_CONFIG_DIR, a machine offline)
#              would otherwise look permanently stale and be re-spawned on
#              every render forever.
#   lane       the sanitized lane this line describes. The reader compares it
#              to its own before trusting the numbers: the filename is
#              sanitized too, and two lanes differing only in stripped
#              characters would otherwise share a file silently — the same
#              collision the statusline's label rule tolerates, made visible
#              here instead, because showing one account's quota under
#              another's name is a different order of wrong than a duplicate
#              label.
#   percent    integer, or "-" when nothing trustworthy was read. Never 0 as a
#              stand-in — a 0 on the border reads as free headroom.
#   model      the scoped model's display name ("Fable"), scrubbed to the same
#              inert charset as the chip's other values because it rides the
#              same two hostile paths: a tmux format string and a quoted
#              set-option.
#   observed   when headroom's figures were observed (epoch seconds), or "-".
#   resets     when the window those figures describe ends, or "-".
#
# observed and resets are both carried because they answer different questions
# and the reader needs both. resets settles whether the number is still ABOUT
# anything: inside a live window usage only ever climbs, so an old reading
# understates and is safe to draw, while a reading whose window has ended
# describes a window nobody is spending against and would read as headroom that
# may not exist. observed is the fallback for the case resets cannot settle —
# a row whose reset instant the vendor left null — where age is the only
# evidence available.
#
# Refreshing is `headroom --json` (the fetching surface, behind headroom's own
# cross-process claim, so concurrent runs are safe and the budget is respected
# without this script knowing anything about it); reading back is
# `headroom limits`, which touches disk alone and spends nothing. The read is
# by EMAIL, not `--account`: headroom knows the primary by its configured name
# ("qiushi") while the lane the statusline computes is an email, and only the
# email identifies both kinds of lane.
#
# Cheap exit is the common case — the lock is held by a sibling pane's spawn,
# or there is no lane to ask about. Always exits 0; a failing refresh must
# leave the chip drawing what it had, not error into a render.

set -u

LANE="${1:-}"
[ -n "$LANE" ] || exit 0

command -v headroom >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# $HOME, never $XDG_CACHE_HOME. The test suite sandboxes by overriding HOME and
# inherits the rest of the environment, so honoring XDG_CACHE_HOME would let a
# machine that happens to set it write the real cache from inside a test run.
CACHE_DIR="$HOME/.cache/claude-ctx"
LANE_KEY="${LANE//[^a-zA-Z0-9._@-]/}"
[ -n "$LANE_KEY" ] || exit 0
CACHE="$CACHE_DIR/$LANE_KEY.quota"
LOCK="$CACHE_DIR/$LANE_KEY.lock"

mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0

# A refresher killed between mkdir and its trap leaves the lock standing, and a
# lock nothing clears would freeze this lane's chip permanently. Sweep one that
# is older than any honest run could still be inside — the whole sequence is
# two headroom invocations, well under a second — before contending.
find "$LOCK" -maxdepth 0 -mmin +2 -exec rmdir {} + 2>/dev/null
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# One line out of headroom's document. The row is selected by DECODED identity
# (kind == "weekly_scoped"), never by the rendered label — "Fable (7d)" is
# prose that changes the day a model is renamed, and headroom's schema 4
# exposes the vendor's own vocabulary precisely so nobody has to match it.
# Rows whose percent or identity fields drifted are dropped rather than shown:
# a row that cannot say what it is about is not a number worth drawing. When
# several scoped weeklies exist the highest wins — it is the one that binds,
# and it self-selects without this script carrying a model name that would go
# stale on its own schedule.
read_lane() {
    headroom limits 2>/dev/null | jq -r --arg e "$LANE" '
      def esc: gsub("[^a-zA-Z0-9._-]"; "");
      ([.accounts[]? | select(.email == $e)] | first) as $a
      | ($a.usage // null) as $u
      | ([$u.limits[]?
          | select(.kind == "weekly_scoped")
          | select(.percent_state == "ok" and .identity_state == "ok")]
         | sort_by(-.percent) | first) as $r
      | if $r == null then "- - - -"
        else
          (($r.model // "") | esc) as $m
          | "\($r.percent | floor) \(if $m == "" then "-" else $m end) " +
            "\(if ($u.observed_at // null) == null then "-" else ($u.observed_at | fromdateiso8601) end) " +
            "\(if ($r.resets_at // null) == null then "-" else ($r.resets_at | fromdateiso8601) end)"
        end
    ' 2>/dev/null
}

# Atomic, because the reader is a bare `read` with no locking of its own: a
# half-written line would parse as a valid line with missing fields.
write_line() {
    local rest="$1" tmp
    # A read that produced nothing — headroom vanished mid-run, jq refused the
    # document — still stamps the attempt, with every field saying "nothing
    # known". Dropping the write instead would re-arm the reader's throttle and
    # spawn this script again on the very next render.
    [ -n "$rest" ] || rest="- - - -"
    tmp="$CACHE.$$"
    printf '%s %s %s\n' "$(date +%s)" "$LANE_KEY" "$rest" > "$tmp" 2>/dev/null &&
        mv -f "$tmp" "$CACHE" 2>/dev/null
    rm -f "$tmp" 2>/dev/null
}

# Cold start: publish whatever is already on disk BEFORE spending ~300ms on a
# fetch, so a pane that has just come up draws a number on its next render
# instead of on the one after the network answers. Skipped once the file
# exists, where it would only rewrite what the reader already has.
[ -e "$CACHE" ] || write_line "$(read_lane)"

# The fetch. Its own output is discarded — it is spent for its side effect on
# headroom's store, which the read below replays. Budget-permitting is
# headroom's decision, not this script's; a refused refresh simply leaves the
# previous observation in place and the read still succeeds.
headroom --json >/dev/null 2>&1

write_line "$(read_lane)"

exit 0
