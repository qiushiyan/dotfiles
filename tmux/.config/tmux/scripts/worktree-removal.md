# Worktree removal and recovery

Satellite of `worktree.md`. Read this when changing merged detection, reap,
batch removal, branch deletion, trash, or recovery refs.

## Safety pipeline

```text
collect target window ids
  → confirm batch + dirty state
  → snapshot dirty work and unmerged branch tips
  → move worktrees to batch trash
  → git worktree prune
  → kill collected windows
  → delete branches by verified merged verdict
  → background-sweep this batch
```

The main worktree and the worktree that launched the popup are never removable.
Declining dirty-work confirmation removes only clean selections. A worktree that
cannot be snapshotted stays in place.

Collect window ids before moving directories: after a rename, a pane's cwd
reports the new path and no longer matches the worktree being removed. Search
all sessions because a deleted cwd is broken wherever its window lives.

## Merged means content reached the base

`wt_merged_into <branch> <base>` is the single verdict used by reap and branch
deletion:

| Integration | Detection |
|---|---|
| merge commit / fast-forward | branch tip is an ancestor |
| squash merge | collapsed branch patch already exists on base |
| rebase merge | every branch commit's patch already exists on base |

Run the graph check first, then patch checks. `git branch -d` sees only graph
ancestry, so a branch proven squash-merged may require `-D`; this is safe only
after the independent patch verdict.

Manual application with edits and merges into a non-default base remain
unproven and require the force path.

## Freshness and cache

A correct algorithm against a stale base is still wrong. The popup starts a
bounded background fetch when `FETCH_HEAD` is stale and waits only when a
verdict is requested. A truncated `FETCH_HEAD` is stale even with a fresh
mtime. Fetch failure is reported instead of silently grading against old state.

Merged verdicts cache on `(branch sha, base sha)` in
`<git-common-dir>/wt-merged-cache`. Ref movement creates a new key, so no
invalidation protocol is needed. A branch-only key could preserve a dangerous
stale `merged` answer.

## Recovery refs

Before destructive work, create `refs/wt-trash/<batch>/<slot>-<branch>`:

- dirty worktree → a commit built with a scratch `GIT_INDEX_FILE`, parented on
  HEAD, including untracked but not ignored files;
- unmerged branch → the branch tip.

Slots prevent ref path collisions between names such as `feat` and `feat/x`.
Print the ref and its recovery command. `@worktree_backup_days` controls expiry;
zero keeps recovery refs indefinitely.

## Trash

Moving to same-filesystem batch trash is immediate even with large dependency
trees. Sweep only that batch in a background tmux job. Startup may reap abandoned
trash older than the age gate; it never removes the whole root, which could race
another live popup.

## Verification

`tests/test-worktree-core.sh` owns merge styles, stale/truncated fetch state,
cache-key poisoning, slot refusal, snapshots, and reap candidates. Popup tests
must also prove dirty-decline behavior, collect-before-move window cleanup, and
that failed snapshots preserve the worktree.
