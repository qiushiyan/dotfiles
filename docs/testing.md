# Tests

This repo is mostly configuration, so there is no build. Two suites, both
runnable with an optional list of case ids to narrow the run:

```bash
bash tmux/.config/tmux/scripts/tests/test-pane-control.sh [T5 T14 …]
bash claude/.claude/skills/handoff/handoff-path.test.sh   [T3 T7 …]
```

The first covers the tmux pane control plane, building throwaway tmux servers on
their own sockets; the second covers handoff baton path resolution.

## A test that escapes its sandbox corrupts live state

This is the constraint that governs both suites. Because the repo's files _are_
the user's live configuration, a test that reaches past its sandbox doesn't fail
— it quietly damages the running system. Both escape routes are silent, so a new
case has to close them deliberately.

**Drive tmux only through the test socket.** Every call goes through the `R()`
helper with `$TMUX` pointed at the suite's own socket. A call that skips it
falls through to the default socket — the real server — where the test's pane
ids don't exist, so everything no-ops and the assertions pass for the wrong
reason. A green suite that tested nothing is the failure mode to fear here.

**Redirect shared state that lives _outside_ tmux.** resurrect's save directory
is a single path shared by all servers unless `@resurrect-dir` is set, so a test
reaching the real `save.sh` overwrites the user's session snapshot; `fresh()`
sandboxes it and T21 asserts the real directory was never touched. Likewise
`handoff-path.sh` creates directories under `$HOME`, so its suite overrides
`HOME` and T11 asserts the real baton store is untouched — ad-hoc verification
that skips the override scatters folders into it for real. Global patterns like
`pkill` need the same care.

Each suite carries a guard case for exactly this reason; when you add state that
crosses the sandbox boundary, add the guard alongside it.
