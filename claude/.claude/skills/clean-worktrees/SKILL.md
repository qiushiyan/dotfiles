---
name: clean-worktrees
description: Clean up merged or inactive Git worktrees, preserving unfinished work and local files. Use for worktree cleanup or the worktree portion of disk cleanup.
argument-hint: "[root] [inactivity window] [audit only]"
---

# Clean worktrees

Remove merged or inactive linked checkouts while preserving unfinished work.
Default to `~/dev/.worktrees` and a 14-day inactivity window. The audit script
collects evidence and proposes candidates; you settle uncertainty and select
the authorized scope. The removal runner checks execution safety, not merge
or inactivity eligibility. An audit-only request stops at the selection.

## Establish the selection

Start with the bundled collector, which writes evidence and a draft plan:

```bash
python3 ~/.agents/skills/clean-worktrees/scripts/audit.py --output /tmp/worktree-audit.json
```

Both scripts' `--help` own their options and the plan schema. Supply the user's
root and inactivity window when different. Use `--repo` to include a repository
whose checkouts beneath the root are all missing; discovery cannot infer its
owner. `--no-fetch` gathers cached evidence and proposes no removals.

Review the report's errors, kept reasons, and integration refs before accepting
candidates. Activity includes checkout history and local-file edits. Keep dirty,
locked, running, or uncertain work. The inactive path requires
the tip to remain reachable from a refreshed remote ref; the merged path
requires proof that the current HEAD reached the intended integration branch.

For unresolved squash/rebase merges, batch GitHub PR metadata by repository,
then query unresolved branches. A matching branch name is insufficient: the
merged PR head must equal or contain the checkout's HEAD. The checkout can
predate the final PR commit or include later unmerged work. Check the PR's target
branch too. List limits are caps, not proof of absence; fetch a missing PR head
only when its ancestry would settle the candidate.

Resolve the draft's candidates and kept records against that evidence, retaining
the full audited HEAD and eligibility reason for each candidate. Audit-only
results use the user's requested format. For cleanup, announce counts and
exceptions, then proceed within the existing authorization.

## Apply the selection

Pass the reviewed plan to the runner:

```bash
python3 ~/.agents/skills/clean-worktrees/scripts/remove.py /tmp/worktree-audit.json --apply
```

It preserves ignored local files outside its disposable cache exclusions,
pins commit tips, retains branch names, and records skips or failures. Its
reported backup directory contains recovery information. Without `--apply`,
it previews execution safety. Keep refusals; forcing removal changes the scope.

Wait for completion using aggregate progress. After interruption, reconcile
recorded results with disk and Git, then refresh eligibility for unresolved
candidates before retrying them. A previously inactive checkout may now be active
even with the same HEAD. Archives and recovery refs remain until a separate
backup cleanup is requested.

Remove registrations whose checkout paths are missing only when individually
verified inside the selected root. Tidy empty ancestors of removed paths without
traversing retained trees. If branch cleanup is also requested, run
`git branch -d` serially after removals and retain refusals; branch/config edits
share repository state. Keep remote branches untouched.

Finish by reconciling remaining paths and registrations with the plan. Report
removed and kept counts, exceptions, recovery location, and measured available
disk-space change, which is approximate while other processes run.

When tuning concurrency or changing safeguards, consult [EVIDENCE.md](EVIDENCE.md).
