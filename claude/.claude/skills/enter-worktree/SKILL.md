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
its configuration. On success, stdout is the absolute worktree path;
diagnostics go to stderr. Pass that path to `session-cd`:

<example>
```bash
path=$(gwt create --non-interactive feat/answer-attachments) &&
  ~/.agents/skills/enter-worktree/scripts/session-cd "$path"
```
</example>

The move applies when your turn ends, so report the branch and let the user know it finished. If `session-cd` fails, enter the path with `EnterWorktree`, or work
from the path when that tool is unavailable.
