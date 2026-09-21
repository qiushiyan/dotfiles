---
name: enter-worktree
description: Name the branch for work that is ready to leave the primary branch, hand back the gwt command that creates it, and move the session there once it exists.
argument-hint: "[scope hint]"
disable-model-invocation: true
---

# Suggest a worktree name

The investigation is done, the session is still on `main`/`develop`, and the
user is about to run `gwt` themselves. Deliver the name, the command and the
reason. `gwt` places the branch at `~/dev/.worktrees/<repo>/<branch>`, so the
branch name is the whole answer — there is no directory to choose.

Name the scope the PR will carry rather than the first fix in it: a name taken
from the symptom goes stale as soon as a second fix joins the branch. Take the
prefix from what the repo uses now, not from memory —

```bash
git branch -r --sort=-committerdate --format='%(refname:short)' | head -20
git worktree list
```

— and keep the name distinct from every branch already in flight there.

Answer in this shape, name first:

<example>
`fix/ux-ask-dock-long-body`

```bash
gwt fix/ux-ask-dock-long-body develop
```

It follows the branch shapes already in the repo (`feat/ux-…`, `fix/…`,
`perf/…`) and names the surface rather than the symptom, so it stays accurate
if the session also takes the transcript chip.
</example>

Pass the base explicitly — the branch the session is on — so `gwt` does not stop
to confirm the fork point. Add one narrower alternative only where the scope
could fairly be read that way. Done when the name, the command and the reason
are on screen and nothing has been created.

Then wait: `gwt` runs in the user's shell, not yours. When they say it exists,
read its path off `git worktree list` and move this session there with
`EnterWorktree` — invoking this skill is the instruction that tool asks for, and
a worktree entered by path is never removed on exit, so `gwt` keeps ownership.
The session's context carries over, so restate the absolute paths the
implementation needs: relative paths now resolve against the worktree, and the
scratchpad root follows the working directory. A session that must pick the work
up cold instead is `/handoff`.
