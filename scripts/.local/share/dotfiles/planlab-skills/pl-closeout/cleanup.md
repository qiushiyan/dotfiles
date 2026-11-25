# Clean up

Remove what the branch started, once the closeout no longer needs it:

- a lane the worktree runs (`lane down` from the worktree), a `tailscale
  serve` it opened, and containers or rig resources named after the branch;
- local branches whose commits are all in the merge: empty `git log
  <PR head>..<branch>` says so;
- the worktree, last, by the sweep's step 6
  (`~/.claude/skills/distill-handoffs/SKILL.md` § Closeout), holds included.

Changes this session did not make, such as an uncommitted file, are
someone else's: leave the worktree to them, and say what is in it.
