# Sidekick runtime integration tests

Run from any directory:

```sh
node --test ~/.claude/skills/sidekick-runtime/tests/runtime.test.mjs
```

The suite places deterministic fake `codex` and `claude` executables first on
`PATH`, runs the public CLI entry points in isolated temporary homes/worktrees,
and verifies their files and process lifecycle. It never invokes a real model.
