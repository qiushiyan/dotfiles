---
name: check-memory
description: Check RAM on the laptop or the mini — memory pressure, swap, what is using it, and dangling processes or VMs that can be freed. Use when the user asks about memory or RAM, a machine feels sluggish, swap or OOM worries come up, or they ask to "check again" after freeing something.
disable-model-invocation: true
---

# Check memory

A **report first, free on a yes** pass over one Mac. The user reads a table,
then answers "free all", "remove them", or names rows; nothing is killed
before that answer.

## 1. Snapshot the machine asked about

`~/.config/machine` names this machine (`mac` or `mini`). For the other one,
pipe the same script over ssh: `ssh mac` from the mini, `ssh qiushi-mini`
from the laptop.

```bash
S=~/.agents/skills/check-memory/scripts/snapshot.sh
bash $S                              # this machine
ssh qiushi-mini 'bash -s' < $S       # or: ssh mac 'bash -s' < $S
```

It prints totals, pressure, swap, compressed memory, load, the top processes
by footprint, per-app sums, Lima/OrbStack VMs, live Claude sessions with
their cwd, and suspects (orphaned dev processes and stopped ones).

## 2. Read it

- **Pressure is the `memory_pressure` free percentage**, with load against
  core count. Low free %, swap near full and high load together mean
  thrashing. Used swap on its own is pages left from an earlier peak: macOS
  drains it slowly, so it stays high after the pressure has gone.
- **Footprint is `top`'s MEM**, which counts compressed pages. RSS undercounts
  anything mostly compressed, such as an idle VM.
- **Attribute every big row to an owner**: a live Claude session (match the
  cwd against the live-session list), an experiment, a desktop app, or
  nothing. `ps -o pid,ppid,stat,etime,rss,command -p <pid>` and the cwd
  settle it.

The usual consumers, from past checks:

| Consumer | Live when | Dangling when | Free with |
|---|---|---|---|
| Lima VM `loopy-drill` (20 GiB) | a running session or replay arm is driving it | load near 0, its master's last log line hours old | `limactl stop loopy-drill` |
| OrbStack engine (~1 GB) | containers or machines running | `docker ps` empty | `orb stop` (restarts on the next `docker`) |
| `tsgo` type-checks (3–22 GB each) | its parent Claude session is alive | parent gone, or one climbing past ~15 GB and swapping | `kill <pid>`; the owning session sees the check fail |
| bench `task-watch-bootstrap.cjs` (~100 MB) | its cwd matches a live Claude session | no live session in that cwd, or the cwd is trashed | `kill <pid>` |
| `loopy-master`, `next-server`, `dev-launcher`, `stub_worker`/`idle-worker` | a live session in the same worktree | `ppid 1` with the cwd under `~/dev/.worktrees/.trash/` or deleted | `kill <pid>` |
| A Claude session in state `T` | — | suspended (Ctrl-Z) for days, often in a deleted worktree | `kill -KILL <pid>`: a stopped process ignores SIGTERM |
| Desktop apps (Arc, Mail, Slack, Teams, Codex) | always | — | the user's call; offer, never quit one unasked |

Live work stays, however large. When it is the problem, name the session
that owns it (pid, worktree, the `limactl start` or command it ran) so the
user can ask that session to stop.

## 3. Report

Lead with one line: RAM total, free %, swap, and whether there is pressure
now. Then a table of what is using memory: what, footprint, owner, live or
dangling with the evidence, and the command that frees it. Close with the
dangling rows offered to free and the large live rows left for the user.

## 4. Free on a yes, then re-measure

- Kill by explicit PIDs. zsh passes an unquoted `$pids` as one argument, so
  write the PIDs out or use an array.
- SIGTERM first, wait a few seconds, confirm each is gone, `kill -KILL` only
  the stragglers. A watcher that reappears may be a new session's own
  watcher; check its cwd before calling it a respawn.
- Rerun the snapshot and show before → after for free %, swap and
  compressed memory. "Check again" later is the same snapshot, diffed
  against the last one.
