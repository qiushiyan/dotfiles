# Clean up

Remove what the branch started, once the closeout no longer needs it:

- a lane the worktree runs (`lane down` from the worktree), a `tailscale
  serve` it opened, and containers or rig resources named after the branch;
- local branches whose commits are all in the merge: empty `git log
  <PR head>..<branch>` says so;
- the worktree, last, by the sweep's step 6 (`distill-handoffs` § Closeout),
  a `hold` line included.

Changes this session did not make, such as an uncommitted file in the
worktree, are someone else's: leave the worktree, and say what is in it.
