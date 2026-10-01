---
name: clean-worktrees
description: Clean up merged or inactive Git worktrees, preserving unfinished work and local files. Use for worktree cleanup or the worktree portion of disk cleanup.
argument-hint: "[root] [inactivity window] [audit only]"
disable-model-invocation: true
---

# Clean worktrees

Remove the linked checkouts under gwt's worktree root whose work has landed
or gone inactive, and keep everything else. Done is every candidate either
removed or kept with a reason, and a report of counts, exceptions, recovery
locations and the disk-space change. An audit-only request stops at the
selection. Defaults: gwt's configured root and a 14-day inactivity window.

The audit collects evidence and proposes candidates; you settle what it
leaves uncertain and choose the authorized scope; the runner removes. Each
script's `--help` owns its options and the plan schema.

## Select

```bash
python3 ~/.agents/skills/clean-worktrees/scripts/audit.py --output /tmp/worktree-audit.json
```

Pass the user's root or window when they differ. `--repo` adds a repository
whose checkouts under the root are all missing, since discovery cannot infer
its owner; `--no-fetch` gathers cached evidence and proposes nothing.

Review the report's errors, kept reasons and integration refs before
accepting a candidate. Keep dirty, locked, running or uncertain work. A merged
candidate needs proof that its current HEAD reached the integration branch,
which the audit takes from `gwt merged`: merge, squash and rebase integration
all count. An inactive candidate needs its tip reachable from a refreshed
remote ref; activity includes checkout history and local-file edits.

PR evidence settles what the audit leaves unresolved, such as work applied by
hand with edits or merged into another branch. Batch GitHub PR metadata by
repository, then query the unresolved branches. A matching branch name proves
nothing: the merged PR's head must equal or contain the checkout's HEAD, and
its target must be the intended branch. List limits are caps, not proof of
absence. Keep each accepted candidate's full audited HEAD and reason in the
plan.

## Remove

```bash
python3 ~/.agents/skills/clean-worktrees/scripts/remove.py /tmp/worktree-audit.json --apply
```

The runner refuses a path outside the root and a checkout a process is
working in, archives the ignored files outside its cache exclusions, then
calls `gwt remove --keep-branch --expect-head <audited HEAD>`. gwt refuses
main, locked, dirty or moved checkouts, keeps branches, and keeps a detached
HEAD as a recovery ref. A refusal is a kept candidate (`skipped`); forcing it
changes the scope. `failed` means the checkout may already be gone, and its
archive is kept: report it with the archive path. The report directory holds
each result, archive and recovery ref. Report directories the runner made
(those with its `plan.json`) expire after gwt's `recovery.keep`
(`gwt config show`), like gwt's own recovery refs; nothing else under the
backup root is touched.

After an interruption, reconcile the recorded results with disk and Git, and
re-audit unresolved candidates before retrying: an inactive checkout may have
become active at the same HEAD. If branch cleanup is also requested,
`gwt remove <branch>` deletes a merged branch that has no checkout; keep its
refusals and leave remote branches alone.

When tuning concurrency or changing safeguards, consult [EVIDENCE.md](EVIDENCE.md).
