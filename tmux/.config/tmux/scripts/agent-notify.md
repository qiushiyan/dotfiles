# Agent-done notifications — dormant reference

**Status: disabled.** `tmux-agent-done.sh` exits before setting any state, so no
dot or `◷ N` badge can appear. The feature was noisy and fragile in daily use;
the inert display and hook wiring remain only to make a future redesign cheap.

Do not add Codex notification wiring while the setter is disabled.

## Model worth keeping

```text
agent hook → tmux-agent-done.sh → window @agent_done
           → tmux-agent-recount.sh → session @agents_ready
           → tmux.conf renders dot + count

navigation binding → clear destination window → recount
```

The clear belongs in the navigation binding. Only the client that pressed the
key knows which window it landed on; a `run-shell` child has no client context,
and `session-window-changed` observes the window being left.

## If it is revived

Treat revival as a redesign, not removal of one `exit 0`:

1. Decide whether an ambient unread badge is still wanted.
2. Keep the setter fast and always successful; a failing Claude `Stop` hook can
   block the agent from stopping.
3. Drive clears from attached-client navigation paths and recount all sessions
   without inferring a current one.
4. Test with an attached client. Relative window navigation is a no-op on a
   detached server and can make a broken clear path look green.
5. Update `tmux/.config/tmux/workflow.md` only after the behavior is live.

Current implementation surfaces:

```text
tmux/.config/tmux/scripts/tmux-agent-done.sh
tmux/.config/tmux/scripts/tmux-agent-recount.sh
tmux/.config/tmux/tmux.conf                 # formats + navigation clears
claude/.claude/settings.json                # completion hooks
```
