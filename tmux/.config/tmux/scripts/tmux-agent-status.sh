#!/usr/bin/env bash
# tmux-agent-status.sh — the one owner of per-pane agent status: the Claude
# context chip, the Codex border markers, and pane-border-status teardown.
#
# lib/agent-vocab.sh defines WHICH options exist; this script owns every verb
# that writes or clears them. Producers never spell the option names:
#
#   Claude statusline   SOURCES this file and calls agent_claude_publish. The
#                       render runs ~3×/s per streaming session, so publishing
#                       must stay one server-side if-shell with no process
#                       spawned (context-chip.md) — a library call, not a verb.
#   Claude hooks        activate claude (SessionStart), clear claude
#                       (SessionEnd).
#   zsh codex wrapper   activate codex, clear codex.
#   zsh precmd          sweep, only after a server-side presence test hit.
#   tmux                reconcile (pane-exited hook, unname-pane, relocation).
#
# VERBS. [pane] defaults to $TMUX_PANE; the hooks pass nothing, by design.
#
#   activate claude [pane]
#       SessionStart (matcher startup|resume|clear|fork — compact continues a
#       live process and is not an activation). Reads the hook JSON on stdin
#       and discharges the pane's tombstone ONLY when it equals its own
#       session id, in one server-side check-and-mutate. Exact match is
#       load-bearing: clearing whatever id is recorded would let an unrelated
#       session's start re-arm a hard-killed predecessor's orphans. It demands
#       nothing else of the pane — dead=A beside a live chip=B is legitimate
#       (switching back to A) and must still discharge. No reconcile:
#       discharge changes nothing visible; the first accepted render redraws.
#   activate codex <path> [pane]
#       The Codex TUI took the pane: record its compact path, mark it live,
#       raise the border. One tmux call; argv, so the path needs no quoting.
#   clear claude [pane]
#       SessionEnd. Reads the hook JSON on stdin and drops the chip only if the
#       recorded owner is its own session (or empty). SessionEnd also fires on
#       /resume switches, where a successor may already own the pane — the
#       owner check keeps the dying session from clearing, or worse
#       tombstoning, its successor. No session id in the payload degrades to
#       the unconditional drop.
#   clear codex [pane]
#       The Codex TUI exited: drop its markers, reconcile.
#   sweep <pane> [agent...]
#       The shell prompt returned in <pane>, so no listed agent still owns it
#       (the zsh caller omits an agent with a SUSPENDED job — a ^Z'd claude
#       keeps its chip). Drops each listed agent's state that is present;
#       Claude's drop tombstones the recorded session, so an orphaned
#       statusline subprocess of a hard-killed claude cannot republish after
#       this cleanup. Default: every kind in AGENT_KINDS.
#   reconcile [target]
#       Recompute pane-border-status for the target's window: top iff some pane
#       is named or carries an agent's presence marker, else back to inherit
#       (global default off). No target, or a gone one → EVERY window: pane
#       relocation moves the pane-local markers between windows, so both the
#       source (stray border) and the destination (hidden chip) need repair,
#       and only an all-window pass reaches a destination whose border is still
#       off. The no-target callers — the pane-exited hook, pane mode's push /
#       put / pick / break, both ends of a float — pass NO #{...} context on
#       purpose: hook-time ids race pane teardown and can RE-RESOLVE to a
#       surviving pane, a mis-target that wrongly strips borders; a sweep of
#       settled state cannot. (tmux has no after-break/join-pane hooks.)
#
# THE CLAUDE OPTIONS (names in lib/agent-vocab.sh):
#
#   @claude_ctx        the context percentage — a value here IS "chip shown";
#                      length, not truthiness, since 0% is a value.
#   @claude_ctx_model  the model id minus its "claude-" prefix. Cosmetic: never
#                      the presence marker, so a pane holding only this draws
#                      nothing.
#   @claude_ctx_effort the reasoning effort in force, drawn as a suffix of the
#                      model ("opus-5[1m]:high") and never without it. Empty
#                      when the model takes no effort parameter.
#   @claude_ctx_account
#                      the account lane the session burns — the email local
#                      part (full email when two lanes share one), for EVERY
#                      lane including the primary; empty means the statusline
#                      could not read an email. Fixed per session; its gate arm
#                      only ever fires to backfill a pane published before the
#                      option existed.
#   @claude_ctx_5h     the account's 5-hour usage, and
#   @claude_ctx_7d     its all-models weekly usage — one group on the border,
#                      both off the vendor payload. Either can go EMPTY on a
#                      live session (API billing carries no rate limits; a
#                      window that reset is dropped), so empty is a value the
#                      gate writes, never a state to skip.
#   @claude_ctx_wk     the MODEL-SCOPED weekly usage, and
#   @claude_ctx_wk_model
#                      the model it is scoped to — one field on the border. The
#                      vendor payload does not carry a model-scoped limit, so
#                      this comes from headroom via the cache
#                      ~/.claude/commands/claude-quota-refresh.sh keeps warm,
#                      and empties once that reading stops describing a window
#                      anyone is still spending against.
#   @claude_ctx_sid    the session that published it (the OWNER).
#   @claude_ctx_dead   the TOMBSTONE: a session id whose publications are
#                      refused from teardown until Claude emits a matching
#                      SessionStart for this pane. Closes the hard-kill race —
#                      a statusline subprocess can outlive its killed Claude
#                      and republish AFTER cleanup — without banning the id
#                      forever: resume KEEPS the session id (verified live
#                      2026-08), so "refused forever" poisoned the same
#                      conversation resumed in the same pane. Known limit,
#                      accepted: after a legitimate discharge, an orphan render
#                      from the OLD run of the same id is indistinguishable
#                      from the resumed run — that needs a per-run token the
#                      vendor does not expose.
#
# RACES. Cleanup is racy by nature (a dying session's orphans, a successor
# session, and the sweeps all touch one pane), so every clear does its
# check-and-mutate in ONE tmux invocation: if-shell -F evaluates the condition
# and queues the chosen branch as a unit, leaving no client-round-trip gap for
# a concurrent publisher. The tombstone is written BEFORE the unsets, reading
# the recorded owner server-side via set-option -F.
#
# THE BORDER ROW is WINDOW-scoped with several interested parties — manually
# named panes, Claude panes, Codex panes — so no producer flips it OFF: each
# updates its own pane's markers and reconciles. Flipping it ON eagerly
# (rename-pane, a publish, activate codex) is safe; it always matches what
# reconcile would compute. "Named" is allow-set-title == 0: the rename-pane
# alias turns it off per pane (that is what freezes a label against OSC
# repaints, see tmux.conf) and nothing else here touches it. If a global
# `allow-set-title off` ever lands, naming needs its own marker.
#
# No-ops outside tmux; always exits 0 — a failing Claude hook surfaces as an
# error.

_AGENT_STATUS_DIR=${BASH_SOURCE[0]%/*}
# shellcheck source=lib/agent-vocab.sh
. "$_AGENT_STATUS_DIR/lib/agent-vocab.sh" 2>/dev/null || { return 1 2>/dev/null || exit 0; }

# --- library: string builders, no subprocesses -------------------------------
# Sourced by the statusline's render path. Everything above the library/verb
# boundary below must stay free of command substitution and external commands.

# agent_claude_publish <pane> <value for each AGENT_CLAUDE_FIELDS entry, in order>
#
# Builds the statusline's single compare-and-set into two globals, run as
#   tmux if-shell -F -t <pane> "$AGENT_GATE" "$AGENT_PUBLISH"
# AGENT_GATE accepts when the tombstone is not this session AND any value
# differs from what the pane holds; at steady state no arm fires and nothing
# is written (set-option costs redraw work even for an unchanged value). The
# owner is an arm too: a successor resuming at its predecessor's exact values
# must still record its own sid, or the predecessor's late cleanup would pass
# its owner check and erase the successor's chip. AGENT_PUBLISH writes every
# field and reconciles the window in the background — accepted writes are
# sparse, and the reconcile doubles as passive repair after relocation.
#
# Values must already be inert text: they land inside a tmux format and a
# single-quoted set-option (the statusline scrubs them). Returns 1 — publish
# nothing — when the count differs from the vocabulary, so a field added there
# before its producer fails closed instead of shifting every value a slot.
agent_claude_publish() {
    local IFS=' ' pane="$1" field value sid="" changed="" sets="" n=0
    shift
    for field in $AGENT_CLAUDE_FIELDS; do n=$((n + 1)); done
    [ "$#" -eq "$n" ] || return 1
    for field in $AGENT_CLAUDE_FIELDS; do
        value="$1"; shift
        [ "$field" = "$AGENT_CLAUDE_OWNER" ] && sid="$value"
        if [ -z "$changed" ]; then
            changed="#{!=:#{$field},$value}"
        else
            changed="#{||:$changed,#{!=:#{$field},$value}}"
        fi
        sets="${sets}set-option -p -t '$pane' $field '$value' ; "
    done
    [ -n "$sid" ] || return 1
    # shellcheck disable=SC2034  # the two results, read by the sourcing statusline
    AGENT_GATE="#{&&:#{!=:#{$AGENT_CLAUDE_TOMBSTONE},$sid},$changed}"
    # shellcheck disable=SC2034
    AGENT_PUBLISH="${sets}run-shell -b 'bash $AGENT_STATUS_BIN reconcile $pane'"
    return 0
}

# agent_present_fmt <agent> — sets AGENT_FMT to a format that is 1 while the
# agent's presence marker holds a value.
agent_present_fmt() {
    case "$1" in
        claude) AGENT_FMT="#{n:$AGENT_CLAUDE_PRESENCE}" ;;
        codex)  AGENT_FMT="#{n:$AGENT_CODEX_PRESENCE}" ;;
        *) return 1 ;;
    esac
}

# agent_drop_cmds <agent> <pane> [sid] — sets AGENT_DROP to the tmux command
# string that retires the agent's state in <pane>, for an if-shell branch.
# Claude's tombstone goes FIRST: the explicit sid, else the recorded owner read
# server-side.
agent_drop_cmds() {
    local IFS=' ' pane="$2" sid="${3:-}" field fields out=""
    case "$1" in
        claude)
            if [ -n "$sid" ]; then
                out="set-option -p -t '$pane' $AGENT_CLAUDE_TOMBSTONE '$sid' ; "
            else
                out="set-option -p -F -t '$pane' $AGENT_CLAUDE_TOMBSTONE '#{$AGENT_CLAUDE_OWNER}' ; "
            fi
            fields=$AGENT_CLAUDE_FIELDS ;;
        codex) fields=$AGENT_CODEX_FIELDS ;;
        *) return 1 ;;
    esac
    for field in $fields; do
        out="${out}set-option -p -u -t '$pane' $field ; "
    done
    AGENT_DROP="${out% ; }"
}

# Sourced as a library: stop before the verbs.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0

# --- verbs --------------------------------------------------------------------

set -u
[ -n "${TMUX:-}" ] || exit 0

# A pane needs the border row when it is named or any agent is present in it.
border_needed_fmt() {
    local IFS=' ' kind cond="#{==:#{allow-set-title},0}"
    for kind in $AGENT_KINDS; do
        agent_present_fmt "$kind" && cond="#{||:$cond,$AGENT_FMT}"
    done
    BORDER_NEEDED="$cond"
}
border_needed_fmt

# Write only on change — set-option triggers redraw work even when the value
# is unchanged. `cur` is the EFFECTIVE value, inherited global folded in.
apply_border() { # <window> <top|off> <current>
    if [ "$2" = top ]; then
        [ "$3" = top ] || tmux set -w -t "$1" pane-border-status top 2>/dev/null
    else
        # unset, not `set off`: inherit the global default, so no per-window
        # residue accumulates
        [ "$3" = top ] && tmux set -w -u -t "$1" pane-border-status 2>/dev/null
    fi
    return 0
}

reconcile_window() {
    local win="$1" want=off
    [ -n "$(tmux list-panes -t "$win" -f "$BORDER_NEEDED" -F x 2>/dev/null)" ] && want=top
    apply_border "$win" "$want" "$(tmux show -wAv -t "$win" pane-border-status 2>/dev/null)"
}

# Every window in two reads, however many windows exist (this runs on every
# pane exit): which windows hold a pane that needs the row, and every window's
# effective value. Writes stay one call per CHANGED window, so a window
# destroyed mid-pass fails alone instead of aborting a batched write.
reconcile_all() {
    local needed win cur
    needed=" $(tmux list-panes -a -f "$BORDER_NEEDED" -F '#{window_id}' 2>/dev/null | tr '\n' ' ')"
    while IFS=' ' read -r win cur; do
        [ -n "$win" ] || continue
        case "$needed" in
            *" $win "*) apply_border "$win" top "$cur" ;;
            *)          apply_border "$win" off "$cur" ;;
        esac
    done < <(tmux list-windows -a -F '#{window_id} #{pane-border-status}' 2>/dev/null)
}

hook_sid() { jq -r '.session_id // empty' 2>/dev/null || true; }

verb="${1:-}"; agent="${2:-}"
case "$verb" in
    activate)
        case "$agent" in
            claude)
                pane="${3:-${TMUX_PANE:-}}"
                [ -n "$pane" ] || exit 0
                sid=$(hook_sid)
                [ -n "$sid" ] || exit 0
                tmux if-shell -F -t "$pane" "#{==:#{$AGENT_CLAUDE_TOMBSTONE},$sid}" \
                    "set-option -p -u -t '$pane' $AGENT_CLAUDE_TOMBSTONE" 2>/dev/null
                ;;
            codex)
                path="${3:-}"; pane="${4:-${TMUX_PANE:-}}"
                [ -n "$pane" ] || exit 0
                tmux set-option -p -t "$pane" "$AGENT_CODEX_PATH" "$path" \; \
                     set-option -p -t "$pane" "$AGENT_CODEX_PRESENCE" 1 \; \
                     set-option -w -t "$pane" pane-border-status top 2>/dev/null
                ;;
        esac
        ;;
    clear)
        pane="${3:-${TMUX_PANE:-}}"
        [ -n "$pane" ] || exit 0
        case "$agent" in
            claude)
                sid=$(hook_sid)
                agent_drop_cmds claude "$pane" "$sid"
                if [ -n "$sid" ]; then
                    # owner check and mutation in one invocation: chip present
                    # AND recorded owner is mine-or-empty → drop, tombstoning MY sid
                    cond="#{&&:#{n:$AGENT_CLAUDE_PRESENCE},#{||:#{==:#{$AGENT_CLAUDE_OWNER},},#{==:#{$AGENT_CLAUDE_OWNER},$sid}}}"
                else
                    cond="#{n:$AGENT_CLAUDE_PRESENCE}"
                fi
                tmux if-shell -F -t "$pane" "$cond" \
                    "$AGENT_DROP ; run-shell -b 'bash $AGENT_STATUS_BIN reconcile $pane'" 2>/dev/null
                ;;
            codex)
                agent_present_fmt codex; agent_drop_cmds codex "$pane"
                tmux if-shell -F -t "$pane" "$AGENT_FMT" \
                    "$AGENT_DROP ; run-shell -b 'bash $AGENT_STATUS_BIN reconcile $pane'" 2>/dev/null
                ;;
        esac
        ;;
    sweep)
        pane="${2:-${TMUX_PANE:-}}"
        [ -n "$pane" ] || exit 0
        shift 2 2>/dev/null || shift $#
        kinds="${*:-$AGENT_KINDS}"
        # One tmux call: one presence-gated drop per agent, each queued as a
        # unit. The reconcile runs here afterwards rather than inside a branch,
        # so two drops cost one reconcile.
        set --
        for kind in $kinds; do
            agent_present_fmt "$kind" && agent_drop_cmds "$kind" "$pane" || continue
            [ $# -gt 0 ] && set -- "$@" \;
            set -- "$@" if-shell -F -t "$pane" "$AGENT_FMT" "$AGENT_DROP"
        done
        [ $# -gt 0 ] || exit 0
        tmux "$@" 2>/dev/null
        win=$(tmux display-message -p -t "$pane" '#{window_id}' 2>/dev/null)
        if [ -n "$win" ]; then reconcile_window "$win"; else reconcile_all; fi
        ;;
    reconcile)
        target="${2:-${TMUX_PANE:-}}"
        win=""
        [ -n "$target" ] && win=$(tmux display-message -p -t "$target" '#{window_id}' 2>/dev/null)
        if [ -n "$win" ]; then reconcile_window "$win"; else reconcile_all; fi
        ;;
    *)
        printf 'usage: %s {activate|clear} {claude|codex} ... | sweep <pane> [agent...] | reconcile [target]\n' "${0##*/}" >&2
        ;;
esac

exit 0
