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

## Merged means content reached the trunk

`gwt` owns the verdict (`~/dev/gwt/README.md` § Listing and merge verdicts):
the popup's `· merged` tag and reap read `gwt list --json`, and branch cleanup
after a removal reads `gwt merged --json <branches>`. One trunk, the remote
default branch, serves all of them and `gwt remove`, so they cannot disagree.

| Integration | Detection |
|---|---|
| merge commit / fast-forward | branch tip is an ancestor |
| squash merge | collapsed branch patch already exists on the trunk |
| rebase merge | every branch commit's patch already exists on the trunk |

`git branch -d` sees only graph ancestry, so a branch proven squash-merged may
require `-D`; this is safe only after gwt's independent patch verdict. A branch
gwt cannot judge counts as unmerged here and is deleted only behind the force
prompt, with its tip kept as a recovery ref. Manual application with edits and
merges into a non-default branch remain unproven and require that path.

## Freshness

A correct algorithm against a stale trunk is still wrong. The popup starts
`gwt trunk --fetch` in the background at launch (a bounded fetch, only when the
trunk is older than gwt's `fetch.max_age`) and waits for it only when reap or
branch cleanup needs a verdict. A failed fetch is reported instead of silently
grading against old state. gwt memoizes verdicts per branch and trunk commit;
the shell's old `wt-merged-cache*` files are deleted at popup startup.

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

After each successful move, remove only that worktree's empty parent directories,
stopping at the repository's worktree root or the first non-empty parent. Never
scan the root recursively: that visits every surviving checkout's dependencies
and can turn a single removal into a minute-long pause.

## Verification

`~/dev/gwt` owns merge styles, trunk choice, stale or truncated fetch state,
and memo keys. `tests/test-worktree-core.sh` owns snapshots, recovery refs and
their expiry, and parent cleanup. `tests/test-gwt-popup.py` drives reap end to
end: gwt's tag, the confirmations, checkout and branch removal, and unmerged
work left alone. Popup tests should also prove dirty-decline behavior,
collect-before-move window cleanup, and that failed snapshots preserve the
worktree.
