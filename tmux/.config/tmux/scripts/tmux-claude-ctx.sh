#!/usr/bin/env bash
# tmux-claude-ctx.sh — lifecycle of the Claude context chip (@claude_ctx) and
# the single owner of pane-border-status teardown.
#
# The chip: Claude Code's statusline script publishes its context-usage integer,
# model id and account lane into per-pane user options on every render
# (compare-and-set, see the tail of ~/.claude/commands/statusline-command.sh);
# pane-border-format draws them right-aligned on the pane's border, shedding
# the cosmetic ones as the pane narrows (see tmux.conf). Five options per pane:
#
#   @claude_ctx        the percentage — presence of a value IS "chip shown"
#   @claude_ctx_model  the model id, minus its "claude-" prefix, drawn left of
#                      the percentage — a display value like the percentage
#                      beside it, not a mirror of the payload. Cosmetic only:
#                      it is never the presence marker, so a pane that somehow
#                      carries just this one draws nothing.
#   @claude_ctx_account
#                      which account lane the session burns — the email local
#                      part for a ~/.claude-accounts/ extra, EMPTY for the
#                      primary, which stays the unmarked lane. Same cosmetic
#                      standing as the model; fixed per session, so it earns
#                      no arm in the publish gate (a new account means a new
#                      session, and the owner arm already accepts that).
#   @claude_ctx_sid    which Claude session published it
#   @claude_ctx_dead   tombstone: a session id whose publications are refused.
#                      Closes the hard-kill race — a statusline subprocess can
#                      outlive its killed Claude and republish AFTER cleanup
#                      ran; the tombstone makes that late write a no-op while
#                      letting a NEW session (different id) publish freely.
#
# Cleanup is racy by nature (a dying session's orphans, a successor session,
# and the sweeps all touch the same pane), so both clear verbs do their
# check-and-mutate in ONE tmux invocation: if-shell -F evaluates the condition
# and queues the chosen branch as a unit, leaving no client-round-trip gap
# where a concurrent publisher could interleave. The tombstone is written
# BEFORE the unsets, and reads the recorded sid server-side via set-option -F.
#
# The border row itself — pane-border-status — is WINDOW-scoped with several
# interested parties (manually named panes, Claude panes), so no producer ever
# flips it OFF directly: each updates its own pane's markers and calls
# `reconcile`, which recomputes the whole window. Flipping it ON eagerly
# (rename-pane alias, statusline publish) is safe — that always matches what
# reconcile would compute.
#
#   clear [pane]        drop the pane's chip, tombstone the recorded session,
#                       reconcile. Caller: the zsh precmd sweep in
#                       tmux-utils.zsh — the prompt returning means no live
#                       Claude owns the pane (the sweep skips a suspended
#                       claude job), so tombstoning what's recorded is safe.
#   clear-session [pane]
#                       SessionEnd variant: reads the hook's JSON on stdin and
#                       acts only if the recorded @claude_ctx_sid is its own
#                       session's (or empty). SessionEnd also fires on /resume
#                       switches, where a successor session may already own
#                       the pane — the owner check keeps the dying session
#                       from clearing (or worse, tombstoning) its successor.
#   reconcile [target]  recompute pane-border-status for the target's window:
#                       top iff some pane is named or carries a chip, else
#                       back to inherit (global default off). No target (or a
#                       gone one) → recompute EVERY window: pane relocation
#                       moves the pane-local markers between windows, so both
#                       the source (stray border) and the destination (hidden
#                       chip) need repair — only an all-window pass reaches a
#                       destination whose border is still off. The no-target
#                       callers — the pane-exited hook, pane mode's push /
#                       mark-move / break verbs (tmux-pane-relocate.sh), and
#                       both ends of a float (tmux-float-pane.sh) — pass NO
#                       #{...} context on purpose: hook-time ids race pane
#                       teardown and can RE-RESOLVE to a surviving pane — a
#                       mis-target that wrongly strips borders; a sweep of
#                       settled state cannot. (tmux still has no
#                       after-break/join-pane hooks, hence caller-level.)
#
# "Named" is detected via allow-set-title==0: the rename-pane alias sets the
# pane-local option off (that's what freezes the label against OSC repaints,
# see tmux.conf), and nothing else in this config touches it — the effective
# value doubles as the marker. If a global `allow-set-title off` ever lands,
# naming needs its own explicit marker instead.
#
# No-ops cleanly outside tmux; always exits 0 (a failing SessionEnd hook would
# surface as a Claude Code error).

set -u

[ -n "${TMUX:-}" ] || exit 0

SELF="$HOME/.config/tmux/scripts/tmux-claude-ctx.sh"

reconcile_window() {
    local win="$1" want=off n ast cur
    while IFS=' ' read -r n ast; do
        if [ "${n:-0}" != 0 ] || [ "${ast:-1}" = 0 ]; then
            want=top
            break
        fi
    done < <(tmux list-panes -t "$win" -F '#{n:@claude_ctx} #{allow-set-title}' 2>/dev/null)
    # write only on change — set-option triggers redraw work even when the
    # value is unchanged. -A folds in the inherited (global) value.
    cur=$(tmux show -wAv -t "$win" pane-border-status 2>/dev/null)
    if [ "$want" = top ]; then
        [ "$cur" = top ] || tmux set -w -t "$win" pane-border-status top 2>/dev/null
    else
        # unset, not `set off`: fall back to inheriting the global default so
        # no per-window residue accumulates
        [ "$cur" = top ] && tmux set -w -u -t "$win" pane-border-status 2>/dev/null
    fi
    return 0
}

sweep() {
    local win
    while IFS= read -r win; do
        reconcile_window "$win"
    done < <(tmux list-windows -a -F '#{window_id}' 2>/dev/null)
    return 0
}

# The shared drop branch: tombstone first (server-side read of the recorded
# sid unless an explicit one is given), then the unsets, then a background
# reconcile — one tmux command string, queued as a unit by if-shell.
drop_branch() {
    local pane="$1" sid="${2:-}"
    if [ -n "$sid" ]; then
        printf "set-option -p -t '%s' @claude_ctx_dead '%s' ; " "$pane" "$sid"
    else
        printf "set-option -p -F -t '%s' @claude_ctx_dead '#{@claude_ctx_sid}' ; " "$pane"
    fi
    printf "set-option -p -u -t '%s' @claude_ctx ; " "$pane"
    printf "set-option -p -u -t '%s' @claude_ctx_model ; " "$pane"
    printf "set-option -p -u -t '%s' @claude_ctx_account ; " "$pane"
    printf "set-option -p -u -t '%s' @claude_ctx_sid ; " "$pane"
    printf "run-shell -b 'bash %s reconcile %s'" "$SELF" "$pane"
}

case "${1:-}" in
    clear)
        pane="${2:-${TMUX_PANE:-}}"
        [ -n "$pane" ] || exit 0
        tmux if-shell -F -t "$pane" '#{n:@claude_ctx}' "$(drop_branch "$pane")" 2>/dev/null
        ;;
    clear-session)
        pane="${2:-${TMUX_PANE:-}}"
        [ -n "$pane" ] || exit 0
        sid=$(jq -r '.session_id // empty' 2>/dev/null) || sid=""
        if [ -n "$sid" ]; then
            # owner check and mutation in the same invocation: chip present
            # AND recorded sid is mine-or-empty → drop, tombstoning MY sid
            tmux if-shell -F -t "$pane" \
                "#{&&:#{n:@claude_ctx},#{||:#{==:#{@claude_ctx_sid},},#{==:#{@claude_ctx_sid},$sid}}}" \
                "$(drop_branch "$pane" "$sid")" 2>/dev/null
        else
            # no session id in the payload — degrade to the unconditional form
            tmux if-shell -F -t "$pane" '#{n:@claude_ctx}' "$(drop_branch "$pane")" 2>/dev/null
        fi
        ;;
    reconcile)
        target="${2:-${TMUX_PANE:-}}"
        win=""
        if [ -n "$target" ]; then
            win=$(tmux display-message -p -t "$target" '#{window_id}' 2>/dev/null) || win=""
        fi
        if [ -n "$win" ]; then
            reconcile_window "$win"
        else
            sweep
        fi
        ;;
esac

exit 0
