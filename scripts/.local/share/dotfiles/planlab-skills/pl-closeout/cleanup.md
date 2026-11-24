# Clean up

Remove what the branch started, once the closeout no longer needs it:

- a lane the worktree runs (`lane down` from the worktree), a `tailscale
  serve` it opened, and containers or rig resources named after the branch;
- local branches whose commits are all in the merge: empty `git log
  <PR head>..<branch>` says so;
- the worktree, last, by the sweep's step 6 (`distill-handoffs` § Closeout).

A `hold` line follows a `gwt remove <path> --keep-branch` line, which removes
the checkout and keeps the branch: run that, then read the `git log` the hold
names. Empty means the branch holds nothing the merge
lacks, so delete it with `gwt`, which keeps a recovery ref. A branch that
holds more stays, and the report says what it holds.

Changes this session did not make, such as an uncommitted file in the
worktree, are someone else's: leave the worktree, and say what is in it.
