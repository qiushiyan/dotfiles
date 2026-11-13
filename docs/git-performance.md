# Git speed in planlab's worktrees

planlab (`~/dev/planlab/main`) is about 46k tracked files, worked on in many
linked worktrees at once on every machine, and `twin` reads every one of
them: `twin status`, and the closing status of `pp` and `twin sync`. A
`git status` there is an lstat of every tracked file and the scan for
untracked files, which the untracked cache lets git skip. A worktree whose
cache holds answers in about 0.1s; one whose cache has gone stale walks some
6,000 directories and takes a second. twin reads them all on every run, so a
finished worktree costs every run until it is removed (the clean-worktrees
skill, `tmux/.config/tmux/scripts/worktree-removal.md`).

## What keeps it fast

- **Config:** `git/.config/git/planlab.gitconfig`, which `git/.gitconfig`
  includes for the clone and its linked worktrees, turns on the untracked
  cache and `fetch.prune`, keeps fsmonitor off (§ Why fsmonitor stays off),
  and leaves maintenance to the agents below.
- **`git-warm`** (`scripts/.local/bin/git-warm`): rewrites the cache of each
  worktree whose cache has gone stale. `com.qiushi.git-warm` runs it on each
  machine at load, hourly, and when planlab's `.git/info/exclude` or the
  global ignore file changes; each rewrite is a line in
  `~/Library/Logs/git-warm.log`.
- **Maintenance:** `com.qiushi.git-maintenance-{hourly,daily,weekly}` run
  git's incremental schedule over every `maintenance.repo` in
  `git/.gitconfig` on each machine: prefetch and the commit-graph hourly,
  loose objects and an incremental repack daily, packed refs weekly.
- **Vnode cache:** a kernel limit a machine with many worktrees needs raised
  by hand (§ Why the vnode cache sets the speed).

## Why the vnode cache sets the speed

Each lstat needs a vnode, and the kernel keeps `kern.maxvnodes` of them:
263,168 by default on every machine here, whatever its memory. That holds
about five of planlab's worktrees. A pass over more evicts what the next pass
needs, so every lstat misses: a status recycles one vnode per tracked file
and takes 0.2s rather than 0.085s, nearly all of it kernel time. The misses
do not spread across processors: 16 worktrees read side by side take 2s past
the limit and 0.4s within it. A status waits for its slowest machine, so the machine with the most
worktrees sets the time for all of them. With the limit raised, a machine
with 19 worktrees reads itself in 0.75s rather than 3.3s.

```bash
sudo sysctl kern.maxvnodes=2000000   # lasts until a restart; nothing restores it
```

A full cache costs about 850 bytes a vnode, 1.7GB at this limit. A filled
cache is not a sign of trouble; recycling is. Read
`vfs.vnstats.num_recycledvnodes` either side of a status: a rise near tracked
files times worktrees means the limit is too low for that machine.

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

## Why fsmonitor stays off

The daemon answers a status only after a cookie file it writes comes back
through FSEvents, and neither that wait nor the client's read has a timeout.
When `fseventsd` stalls, every `git status`, and all that runs on one, hangs
silently for as long as the stall lasts; the laptop and the mini have both
done this. The watchdog in `docs/fseventsd-watchdog.md` restarts a growing
`fseventsd` before it reaches that state. What the daemon saves is one lstat
per tracked file, which is not much: without it a status takes about 0.09s in every worktree while the vnode
cache holds them, because the untracked cache still skips the walk.

## Adding a clone

Add `repo = ~/dev/<path>` under `[maintenance]` in `git/.gitconfig`.
`git for-each-repo` expands `~`, so one line serves every home, and git-warm
reads the same list. The cache settings reach a clone through an `includeIf`
pair like planlab's, and git-warm's watch paths name planlab's exclude file
only.

Never run `git maintenance register` or `git maintenance start`. Register
writes this home's absolute path into the stowed file, wrong on another
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
sysctl kern.maxvnodes              # 263168 after a restart: § Why the vnode cache sets the speed
```

A burst of rewrites across every worktree is an exclude file that changed.
The same worktree rewritten hour after hour means something keeps rewriting
its index without the cache, and is worth finding.
