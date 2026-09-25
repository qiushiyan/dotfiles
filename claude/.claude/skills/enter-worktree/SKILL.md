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

`session-cd` queues Claude Code's `/cd`, which keeps the session in the
worktree across quit and resume. The move happens when your turn ends, and
commands you run before that still use the old directory. So make it the
turn's last action: report the branch and path, then end the turn. The work
continues in the worktree on the user's next message.

When `session-cd` exits non-zero, its stderr gives the reason. Enter the path
with `EnterWorktree` when available; otherwise use it as the working directory
for subsequent commands.
