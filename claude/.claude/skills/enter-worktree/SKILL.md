---
name: enter-worktree
description: Create and move into a worktree for implementation
disable-model-invocation: true
---

Create a worktree for the design or implementation discussed in this session,
then move the session into it. Choose a branch name that describes the goal and
scope, using the repository's naming conventions.

Use `gwt create --non-interactive` with the chosen branch. Supply a base as
the next argument when the discussion chooses one; otherwise let gwt apply
its configuration.

<example>
```bash
gwt create --non-interactive feat/answer-attachments
```
</example>

On success, stdout is the absolute worktree path; diagnostics go to stderr.
Use that returned path with `EnterWorktree` when available. In an agent without
that tool, use the path as the working directory for subsequent commands.
Report the branch and path once the session is working there.
