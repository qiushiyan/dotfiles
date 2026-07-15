# Sidekick runtime integration tests

Run from any directory:

```sh
node --test ~/.claude/skills/sidekick-runtime/tests/runtime.test.mjs
```

The suite places deterministic fake `codex` and `claude` executables first on
`PATH`, runs the public CLI entry points in isolated temporary homes/worktrees,
and verifies their files and process lifecycle. Coverage includes realtime
Claude stream-json, heartbeat visibility during semantic silence, fragmented JSON and UTF-8,
stdout/stderr separation, partial-result recovery, same-turn transcript
fallback, atomic metadata, live/stale resume locking, terminal-result vs.
hard-cap cleanup races, timeout/interruption process-tree cleanup, legacy cap
preservation, abandoned/orphaned reconciliation, and pending discovery. It never
invokes a real model.
