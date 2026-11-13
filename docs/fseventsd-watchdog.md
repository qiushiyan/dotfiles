# fseventsd watchdog

`fseventsd` is the macOS service that tells programs which files changed:
Spotlight, Time Machine, Finder and iCloud use it, and so does every dev tool
that watches files (next dev's reload, vitest's watch mode, editors,
OrbStack's file sharing, git's fsmonitor). On these machines it sometimes
grows from tens of megabytes to tens of gigabytes within days, with its CPU
pegged, file events stalled or lost, and swap full. Nothing here has found
why. `fseventsd-watchdog` (`scripts/.local/bin/fseventsd-watchdog`, whose
header owns the mechanism) restarts it before it gets that far, as a
root LaunchDaemon on each machine.

## Why restart it rather than turn it off

`fseventsd` is a system service under System Integrity Protection, and
launchd starts it again when it exits. Even if it could be stopped, dev
servers would stop reloading on save, Spotlight would go stale, and Time
Machine would scan the whole disk on every backup.

A restart costs less. Spotlight and Time Machine rescan once to cover the
event history the old process lost, and a watcher may miss a file change
made during the restart. git's fsmonitor stays off in planlab for a related
reason: a stalled `fseventsd` hangs every `git status` that waits on it
(`docs/git-performance.md` § Why fsmonitor stays off).

## Why the limit is 2 GB

These readings come from the sessions that ran into the problem. Each is
the footprint (top's MEM, which counts compressed and swapped pages) unless
it says RSS:

| Machine | Date | Running for | Size | State |
|---|---|---|---|---|
| mini | 2026-10-13 | 10 d | 6 MB RSS | healthy |
| mini | 2026-10-15 | 13 d | 1.0 GB | growing |
| mini | 2026-10-16 | 14 d | 10–11 GB | 100% CPU, `git worktree add` stuck for minutes |
| mini | 2026-10-22 | 20 d | 60 GB | swap 41 of 43 GB |
| laptop | 2026-10-24 | 87 d | 10 GB, growing | 94% CPU |
| laptop | 2026-10-30 | 93 d | about 15 GB | 150–290% CPU, file events lost, `git status` hung |
| mini2 | 2026-11-09 | 7 d | 17–39 MB RSS | healthy |
| mini2 | 2026-11-13 | 11 d | 37 GB | swap 32 GB, load 35 on 15 cores |
| laptop | 2026-11-13 | 14 d | 6.5 MB | healthy |
| mini | 2026-11-13 | 22 d | 48 MB | healthy |

A healthy process stays in the tens of megabytes however long it runs. No
reading above about 50 MB was healthy, and none of the larger ones came back
down without a restart. Symptoms appeared by 10 GB. The limit sits 40 times
above the largest healthy reading and 5 times below the first symptoms.

A small limit also keeps the restart cheap. A process told to exit first
reads its whole footprint back in from swap. At 37 GB that took more than a
minute and then had to be force-killed; at 2 GB it should take seconds.

The table holds about fifteen readings, so treat the limit as provisional.
The watchdog records the footprint every five minutes, and
`fseventsd-watchdog status` prints the 24-hour and 7-day peaks. If a healthy
machine's peaks approach 2 GB, raise `LIMIT_MB` in the script and reinstall
on every machine.

## Installing it on a machine

The LaunchDaemon runs a root-owned copy of the script, because a root job
that runs a file in this checkout gives root to anything that can edit the
file. That means `twin dotfiles apply` never reaches the daemon. A machine
gets the script, and every later edit to it, only through its own install:

```bash
twin repos pull dotfiles && twin dotfiles apply    # puts the command in ~/.local/bin
sudo ~/.local/bin/fseventsd-watchdog install
fseventsd-watchdog status                          # "installed and current"
```

`sudo` asks for that machine's password. Run the install in a terminal of
your own on that machine, or over `ssh -t <host>`. An agent cannot type a
password, so an agent session hands this step to you. `status` says when the
installed copy differs from the checkout. `sudo
~/.local/bin/fseventsd-watchdog uninstall` removes the daemon and its copy,
and keeps the logs.

## Reading what it did

`fseventsd-watchdog status` shows whether the daemon is installed and
current, the process's size now, its recent peaks, and the latest events.
The `/check-memory` snapshot prints the same in one line. The logs are under
`/Library/Logs/fseventsd-watchdog/` and are readable without `sudo`:

- **`restarted: … exited on SIGTERM`:** the normal case.
- **`restarted: … ignored SIGTERM for 30 s, killed`:** the process grew too
  large to exit quickly. If this keeps appearing, the limit is too high.
- **`restart held, the last was N min ago`:** the process passed the limit
  again within an hour of a restart. Something keeps driving the growth, and
  more restarts will not fix it. Find what is writing files: a run of these
  lines means the restarts are only hiding that cause.
- **`still running after SIGKILL`:** the restart failed. Check by hand with
  `ps -o pid,etime -p $(pgrep -x fseventsd)`.

To restart it by hand on a machine without the watchdog, run
`sudo killall -KILL fseventsd` in your own terminal. A plain `killall` sends
SIGTERM, which waits while the process pages its whole footprint back in.
