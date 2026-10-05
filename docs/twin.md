# Working across the laptop and the mini (`twin`)

The laptop (`mac`) and the office mini (`mini`) are both worked on, and
neither is a copy of the other. Every repository, this one included, is an
ordinary clone on each. `twin` (`~/dev/twin`, on PATH on both) covers what
git does not: it says what is unsent on both machines, moves the gitignored
files a manifest lists, and has each machine build and activate for itself.
`twin help` lists the commands; this page is when to reach for which.

`docs/qiushi-mini.md` is the mini as a machine: reaching it, its desk, its
toolchain, the jobs it hosts.

## What moves, and how

- **Tracked content moves by git and nothing else.** Commit, push, and pull
  on the other machine. `twin` never commits, pushes or merges, and it
  changes tracked files only inside `twin repos pull` and `twin repos clone`.
- **Gitignored files move only when the manifest names them.** These are the
  carried paths: env files, token files, working notes, `~/.secrets.shared`.
  The laptop reconciles them with the mini through Unison, every hour and on
  `twin files sync`.
- **Built things never move.** CLIs, the TabType app, stow links, the Codex
  config and launchd agents are made on each machine from its own clone
  (`twin tools install`, `twin dotfiles apply`).
- **Nothing else travels.** Uncommitted work, a branch with no upstream,
  OAuth logins (Claude Code, Codex and gh are logged in on each machine; a
  shared refresh token logs the other out), `~/.secrets`, `node_modules` and
  other build output.

The manifest is `twin/.config/twin/twin.toml`, stowed to
`~/.config/twin/twin.toml`. It is the whole declaration: the repositories
both machines hold, each one's carried paths, the tools each machine builds,
and the packages the mini stows. `~/.config/machine` tells `twin` which
machine it is on, and it refuses to run without it.

## `twin status`

Run it before leaving a desk and on sitting down at the other. It inspects
this machine, asks the other for the same, and ends with the attention
block: one line per thing a person must act on, with the command that clears
it. Exit status 0 means nothing needs attention on either machine, 1 means
something does, 2 means the command itself failed.

- **uncommitted, unpublished:** work that exists on that machine only. Commit
  and push it there.
- **local-only, in use:** a branch with no upstream, checked out in a
  worktree. Push it if the work continues on the other machine; it is
  expected for a worktree whose work stays put.
- **behind:** the upstream moved, as of that machine's last fetch.
  `twin repos pull <target>` there.
- **absent:** the manifest registers a repository that machine has no clone
  of. `twin repos clone <target>` there.
- **tool behind, activation behind, codex config behind:** the checkout moved
  and what is installed or stowed did not. `twin tools install <tool>` or
  `twin dotfiles apply`, on that machine.
- **needs resolving, blocked, not enrolled:** a carry set; see § Carried files.
- **not reachable:** the other machine did not answer. Its lines then carry
  the time they were recorded. An unreachable machine is never shown as clean.

A status command with no target folds a repository's many items under one
condition into a counting line; `twin status <target>` lists each, and
`--json` always carries them all. Nothing in status fetches: "behind" is as
of the last fetch, which the hourly tick does on each machine.
`twin status --recorded` skips the call to the other machine.

A Claude Code session started in this repository gets its machine's text and
`twin status dotfiles --recorded` at session start
(`.claude/hooks/machine-context.sh`).

## Common cases

- **A commit made here is needed there.** Push here. There:
  `twin repos pull <target>`, which fast-forwards only, and refuses a dirty
  or diverged worktree with its reason. `pp` is this for the planlab checkout
  and its briefs on both machines at once (`--both`).
- **The pulled repository is dotfiles.** Then `twin dotfiles apply` there. A
  pull does not restow, render the Codex config or re-read `tmux.conf`; apply
  does. It loads launchd agents only with `--load-agents`.
- **The pulled repository is a tool.** Then `twin tools install <tool>`
  there. This includes `twin` itself: each machine calls the other's over
  ssh, so install it on both after a change.
- **Work on a branch continues on the other machine.** Push the branch with
  an upstream before leaving; there, fetch and switch to it. A linked
  worktree is pulled from inside it (`twin repos pull` with no target).
- **A carried file changed.** Nothing to do: it reaches the other machine at
  the laptop's next hourly run. For now, `twin files sync <target>` from
  either machine.
- **A key both machines need.** Write it in `~/.secrets.shared`. A key for
  one machine goes in that machine's `~/.secrets`, which is never carried.
  `.zshrc` sources both.
- **A new repository should live on both.** Add `[repos.<name>]` to the
  manifest with its gitignored working files under `carry`; commit, push,
  pull and apply on the other machine. There: `twin repos clone <name>`. On
  the laptop: `twin files enroll <name>`, read the listing, then again with
  `--copy-missing` to send the files the new clone lacks.
- **A repository gains a carried path.** Add it to `carry`, bring both
  machines to that dotfiles commit, then `twin files enroll <target>` again:
  a path the enrollment does not cover blocks the target until then.
- **A new personal CLI.** Give its repository a `make install` target and add
  `[tools.<name>]` with `method = "make-install"`. A pinned pnpm global is
  `pnpm-global`; upgrading one is changing its pin, then installing on each.
- **A TabType release.** The laptop installs it by its release runbook; on
  the mini, `twin tools install tabtype` downloads and installs the same
  release. Status names the machine on the older release.
- **A package should be stowed on the mini.** Add it to `packages` under
  `[machines.mini]`. The laptop stows the `Makefile`'s default set.
- **A launchd agent.** Put its plist in the package of the machine that runs
  it, `launchd-mac/` or `launchd-mini/`: a plist carries its machine's home
  path, and the `Makefile` stows only the package `~/.config/machine` names.
  Then `twin dotfiles apply --load-agents` there.
- **A Codex setting.** Edit `twin/.config/twin/codex/shared.toml`, or
  `mac.toml` / `mini.toml` for one machine, then `twin dotfiles apply` on
  each. `~/.codex/config.toml` is a rendered file, never a link.
- **The laptop is asleep and you are on the mini.** Git, pulls, installs and
  status all work, and the laptop's lines are its last recorded ones. Carried
  files do not move, and a `twin files` command fails naming the laptop.

## Carried files

A carry set is reconciled, not copied in a direction: a file changed on one
machine reaches the other, whichever it was. The cases where that cannot be
decided stop and wait.

- **Changed on both machines, or deleted on one: nothing is overwritten.**
  The path is listed as needing resolution in every run until
  `twin files resolve <target> <path> --keep mac|mini` (that machine's copy
  wins) or `--delete` (every copy goes). The copy a resolution replaces or
  removes is first kept under `~/.local/state/twin/replaced/` on the machine
  that held it; remove those by hand.
- **Enrollment is explicit.** `twin files enroll <target>` is the first
  reconciliation of a target: it lists what is equal, what differs and what
  exists on one machine only. A one-sided path is copied only with
  `--copy-missing`; otherwise it is held until resolved. An ordinary sync
  never initialises a target.
- **Blocked is cleared by fixing the cause, or by enrolling again** when the
  item says so: a lost record, a receipt on one machine only, a path the
  enrollment does not cover.
- **Both machines must declare the target alike.** When their dotfiles
  commits differ in a target's carry set, nothing is reconciled and the item
  names both commits. Pull and apply on the machine that is behind.
- **Copies equal in content and different in mode wait at enrollment.** The
  listing says so. `chmod` one to match, then sync.
- **What may be carried.** A literal path, no wildcard, that git ignores. A
  carried directory may hold files git tracks beside its ignored ones; those
  stay git's. Refused: a tracked file; a directory holding a file git neither
  tracks nor ignores; anything under `node_modules` or other build output;
  `~/.ssh`, `~/.gnupg`, `~/.secrets`, gh's config, `~/.claude`, `~/.codex`.
  Finder's `.DS_Store` is never carried.
- **A pull is refused when the incoming commits add a file where a carried
  one sits.** Git treats an ignored file as expendable and would replace it.
  Move the carried file aside or drop it from the manifest, then pull.
- **A carried copy is a replica, not a backup.** An edit, a truncation
  included, reaches the other machine. `docs/recovery.md` owns backups.
- **The mini is not a trust boundary** (`docs/qiushi-mini.md` § Reaching the
  laptop). Whatever is carried is readable by every agent session there,
  which is why a key's reach is decided by the file it is written in.

## The hourly tick

`com.qiushi.twin-tick`, in each machine's launchd package, runs `twin tick`
at load and every hour. On the laptop it reconciles every enrolled carry
set, fetches every registered repository and exchanges observations with the
mini; on the mini it fetches and records. It never pulls, installs or
applies, so it changes no tracked file and nothing a running session has
open. Its log, `~/Library/Logs/twin-tick.log`, ends with that machine's
attention block as of the last run.

## Codex config

Codex writes trust decisions into `~/.codex/config.toml` as it runs, and its
desktop app writes its plugins and MCP servers there, so the file cannot be
a link into this repository. `twin dotfiles apply` renders it from the
shared source, this machine's fragment, and the tables those programs own,
kept from the local file (`codex_runtime_tables` in the manifest). A setting
changed in the local file outside those tables, a `/model` default included,
is reported as drift and stops the next render: move it into the source, or
discard it with `--replace-codex-config`. `skill-sync` writes its generated
block into the shared source, so its changes also reach Codex at the next
apply.

## Why it is shaped this way

- **Neither machine is authoritative, for any kind of state.** A mirror from
  the laptop loses whatever is edited on the mini, without notice, at the
  next sync; every transport here is git or a reconciler, and neither takes
  a direction.
- **Carried paths are an allowlist.** "Everything git ignores, minus
  artifacts" copies `node_modules` the first time an exclusion is forgotten.
- **A conflict or a deletion stops and reports.** A destroyed secret costs
  more than a manual step.
- **Unknown is not clean.** A sleeping machine, a failed fetch and a missing
  record are each reported as what they are.
- **The timer integrates nothing.** Pulling on a schedule would rewrite code
  under a running session; pushing on one would publish unreviewed work.
- **Uncommitted work and unpushed branches do not travel.** Carrying them
  needs a second transport beside git, for work that is either a forgotten
  push or throwaway. Status is the reminder.
- **Only the laptop reconciles.** One machine holds the reconciler's lock and
  record of each target, so a carry set is never reconciled by two runs.

`twin`'s own rules and tests are in `~/dev/twin` (`CLAUDE.md`,
`internal/files/files.go`'s header). Its state is `~/.local/state/twin` on
each machine.
