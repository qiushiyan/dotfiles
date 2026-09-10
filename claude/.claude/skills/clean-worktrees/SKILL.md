---
name: clean-worktrees
description: Clean up merged or inactive Git worktrees, preserving unfinished work and local files. Use for worktree cleanup or the worktree portion of disk cleanup.
argument-hint: "[root] [inactivity window] [audit only]"
---

# Clean worktrees

Remove eligible linked checkouts and leave a concise account of what was
removed, retained, and recoverable. Default to `~/dev/.worktrees` and **merged
or inactive for 14 days**, unless the user supplies different criteria.
A cleanup request authorizes the eligible removals; an audit request stops at
the selection. Keep the main checkout, running work, and uncommitted changes.

## Establish the selection

Discover linked checkouts beneath the selected root, group them by Git common
directory, then read each repository's worktree registry. Stop descending once
a checkout is found: walking dependency trees makes discovery needlessly slow.
Include detached checkouts and missing registrations in the inventory.

Fetch each relevant remote once and use bounded concurrency for independent
reads. Record a reason and the full current HEAD for every selected checkout:

- **Merged:** HEAD is contained in the refreshed integration branch, or a merged
  PR's head contains HEAD. Check ancestry against the PR's commit, not just its
  branch name: the checkout may predate the final PR commit, or contain later
  unmerged work. Confirm the PR landed in the intended integration branch.
- **Inactive:** the newest commit timestamp, checkout/HEAD reflog timestamp,
  and tracked or untracked file modification is older than the cutoff. A last
  commit date alone misses an old branch checked out yesterday. Exclude
  generated files from this activity measure; recent local work is a keeper.
- **Keep:** dirty, locked, in use by a process, recently unmerged, or uncertain.
  For inactive unmerged work, require the tip to be reachable from a refreshed
  remote ref; otherwise keep and identify the unpushed commits. Failed status,
  fetch, or process checks are unknowns, not evidence of safety.

For GitHub squash merges, batch PR metadata by repository, then query only
unresolved branches. List limits are caps, not proof of absence. Fetch a missing
merged head only when its ancestry would settle an unresolved candidate.

For removal, write the audited selection as JSON. For an audit-only request,
report the selection in the user's requested format. The runner's `--help`
owns the execution plan's schema:

```bash
python3 ~/.agents/skills/clean-worktrees/scripts/remove.py --help
```

The plan contains the canonical root, candidate paths with full HEADs and
eligibility evidence, and optional kept records. Announce the counts and
exceptions before applying it; continue within the user's existing scope.

## Apply the selection

Use the bundled runner rather than hand-writing a removal loop:

```bash
python3 ~/.agents/skills/clean-worktrees/scripts/remove.py /path/to/plan.json --apply
```

Without `--apply`, it checks and previews the selection. It executes normal
`git worktree remove` in a bounded worker pool, rechecks each checkout after
backing up ignored local files, and records per-checkout results outside the
cleanup root. Its exclusions are disposable dependency/cache directories;
symlinks are archived as links, with their targets untouched. Backup failure
keeps the checkout. Index flags that can hide local edits also keep it, because
Git's ordinary dirty check misses those edits. Recovery refs pin removed tips,
including detached commits.

The runner applies eligibility decisions from the audit; it does not establish
merge or inactivity itself. It preserves branch names. If branch cleanup is
also requested, run `git branch -d` serially after removals and retain refusals;
branch/config edits share repository state. Keep remote branches untouched.

Wait for the batch to finish. Use its periodic aggregate progress and durable
results instead of polling every few seconds or narrating each deletion. On
interruption, reconcile each recorded result with disk and Git before retrying
only unresolved candidates. Keep failed checkouts; forcing through a refusal
changes the cleanup's scope.

Remove missing registrations only when individually verified inside the selected
root. Tidy empty ancestors of removed paths without traversing retained trees.
Verify remaining registrations and paths against the plan, then report removed
and kept counts, exceptions, the backup/report location, and the measured change
in available disk space. That change is approximate when other processes run.
Archives and recovery refs remain until a separate backup cleanup is requested.

Performance and safety evidence, including concurrency limits: [EVIDENCE.md](EVIDENCE.md).
