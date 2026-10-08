# Git speed in planlab's worktrees

planlab (`~/dev/planlab/main`) is about 31k tracked files, worked on in many
linked worktrees at once on both machines, and `twin` reads every one of
them: `twin status`, and the closing status of `pp` and `twin sync`. Nearly
all of a `git status` there is the scan for untracked files, which the
untracked cache and fsmonitor let git skip. A worktree whose cache holds
answers in about 0.1s; one whose cache has gone stale walks some 6,000
directories and takes a second. twin reads them all on every run, so a
finished worktree costs every run until it is removed (the clean-worktrees
skill, `tmux/.config/tmux/scripts/worktree-removal.md`).

## What keeps it fast

- **Config:** `git/.config/git/planlab.gitconfig`, which `git/.gitconfig`
  includes for the clone and its linked worktrees, turns on the untracked
  cache, fsmonitor (a daemon per worktree) and `fetch.prune`, and leaves
  maintenance to the agents below.
- **`git-warm`** (`scripts/.local/bin/git-warm`): rewrites the cache of each
  worktree whose cache has gone stale. `com.qiushi.git-warm` runs it on each
  machine at load, hourly, and when planlab's `.git/info/exclude` or the
  global ignore file changes; each rewrite is a line in
  `~/Library/Logs/git-warm.log`.
- **Maintenance:** `com.qiushi.git-maintenance-{hourly,daily,weekly}` run
  git's incremental schedule over every `maintenance.repo` in
  `git/.gitconfig` on each machine: prefetch and the commit-graph hourly,
  loose objects and an incremental repack daily, packed refs weekly.

## Why a cache goes stale and stays stale

Each worktree keeps its untracked cache in its own index, keyed to the
shared `.git/info/exclude` and the global ignore file. A change to either
invalidates every worktree's cache at once, and tools append their own
directories to `info/exclude` as they run. Only a command holding the index
lock writes a rebuilt cache back, and twin and gwt never take it, because
they read worktrees a person or an agent may be committing in. A worktree in
use heals at its next commit or plain `git status`; an idle one stays slow
until git-warm rewrites it.

git-warm reads each worktree without the lock first, and takes it only where
that read showed a stale cache. A commit started in that worktree during the
sub-second rewrite fails with `index.lock exists`, and succeeds when run
again.

## Adding a clone

Add `repo = ~/dev/<path>` under `[maintenance]` in `git/.gitconfig`.
`git for-each-repo` expands `~`, so one line serves both homes, and git-warm
reads the same list. The cache settings reach a clone through an `includeIf`
pair like planlab's, and git-warm's watch paths name planlab's exclude file
only.

Never run `git maintenance register` or `git maintenance start`. Register
writes this home's absolute path into the stowed file, wrong on the other
machine; start also installs `org.git-scm.git.*` agents that run
maintenance a second time beside these. On a machine that has them:

```bash
for s in hourly daily weekly; do
  launchctl bootout gui/$(id -u)/org.git-scm.git.$s
  rm ~/Library/LaunchAgents/org.git-scm.git.$s.plist
done
```

## When status is slow

```bash
pp --trace; twin trace             # which worktrees' git status took the time (docs/twin.md § A run was slow, or failed partway)
git-warm -n                        # each worktree whose cache is stale; rewrites nothing
git-warm                           # rewrite them now
tail ~/Library/Logs/git-warm.log   # each rewrite, with what the read before it measured
```

A burst of rewrites across every worktree is an exclude file that changed.
The same worktree rewritten hour after hour means something keeps rewriting
its index without the cache, and is worth finding.
