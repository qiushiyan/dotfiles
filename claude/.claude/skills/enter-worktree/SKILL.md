---
name: enter-worktree
description: Create and move into a worktree for implementation
disable-model-invocation: true
---

Create a worktree for the design or implementation discussed in this session,
then move the session into it. Choose a branch name that describes the goal and
scope, using the repository's naming conventions.

Use the installed binary in non-interactive mode. An omitted base forks from
the configured base (current HEAD by default); pass a base explicitly when
the discussion calls for one.

```bash
gwt create --non-interactive feat/answer-attachments
# stdout: absolute path under the configured worktree root

gwt create --non-interactive fix/ask-dock-long-body develop
```

On success, stdout is the absolute worktree path; diagnostics go to stderr.
Use that returned path with `EnterWorktree` when available. In an agent without
that tool, use the path as the working directory for subsequent commands.
The binary creates the checkout without changing this session's directory.
Report the branch and path once the session is working there.
