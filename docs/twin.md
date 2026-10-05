# Working across the laptop and the mini (`twin`)

The laptop (`mac`) and the office mini (`mini`) are both worked on, and
neither is a copy of the other. Every repository, this one included, is an
ordinary clone on each. `twin` (`~/dev/twin`, on PATH on both) covers what
git does not: it says what is unsent on both machines, moves the gitignored
files a manifest lists, and has each machine build and activate for itself.

`docs/qiushi-mini.md` is the mini as a machine: reaching it, its desk, its
toolchain, the jobs it hosts.

## What moves, and how

```text
tracked content            git: commit, push, pull on the other machine
carried paths              twin: gitignored files the manifest lists, reconciled by the laptop
CLIs, apps, stow links,    never move: each machine builds from its own clone
  Codex config, agents
uncommitted work,          nothing: commit and push, or it stays where it is
  branches with no upstream
OAuth logins, ~/.secrets,  nothing: per machine by design
  node_modules, build output
```

`twin` never commits, pushes or merges. It changes tracked files only when a
person runs `twin sync`, `twin repos pull` or `twin repos clone`; the hourly
tick never does.

The manifest is `twin/.config/twin/twin.toml`, stowed to
`~/.config/twin/twin.toml`: the repositories both machines hold, each one's
carried paths, the tools each machine builds, the packages the mini stows.
`~/.config/machine` (`mac` or `mini`) tells `twin` where it is; without it
`twin` refuses to run.

## Status

```bash
twin status                 # both machines; run before leaving a desk and on sitting down
twin status dotfiles        # one target, every item listed; only it is inspected
twin status --recorded      # do not ask the other machine; show its last recorded state
twin status --json          # the same items, for a program
twin repos status           # only repositories; also lists unregistered checkouts under ~/dev
twin files status           # only carry sets
twin tools status           # only tools
```

```text
attention: 3
  mac dotfiles: unpublished — main is 2 ahead of origin/main. Clear: git push
  mini planlab: behind — develop is 10 behind origin/develop as of the fetch at 2026-10-05 14:02. Clear: twin repos pull planlab
  mini (recorded 2026-10-05 09:12) itell: uncommitted — 3 paths in ~/dev/itell. Clear: commit or discard
```

The attention block is the last thing every command prints. Each line is
machine, target, condition, and the command that clears it; run that command
on the machine the line names.

```text
exit 0   nothing needs attention on either machine
exit 1   something does
exit 2   the command itself failed
```

- **uncommitted, unpublished, local-only in use, behind:** work in a main
  checkout, or on a branch both machines have checked out. A main checkout
  is what both machines pull, so work left there is work the other lacks;
  `local-only, in use` is a branch with no upstream checked out there.
  `behind` is as of that machine's last fetch: status never fetches; the
  hourly tick does.
- **own work** (informational): the same conditions in a linked worktree,
  or on a branch ahead of its upstream that neither machine has checked out.
  It becomes attention once the other machine checks out the same branch.
- **absent:** registered in the manifest, no clone on that machine.
- **not registered:** the other machine's manifest does not list the
  repository; pull and apply dotfiles there.
- **tool behind, activation behind, codex config behind:** the checkout moved
  and what is installed or stowed did not.
- **tool differs:** each machine built the tool from a different commit,
  usually because their checkouts are on different branches. Each is current
  against its own checkout, so nothing else would say it.
- **needs resolving, blocked, not enrolled:** a carry set (§ Carried files).
- **not reachable:** the other machine did not answer, and its lines come
  from the record of it, each carrying when its target was seen. An
  unreachable machine is never shown clean.

With no target, a repository's many items under one condition fold into one
counting line, and informational lines of one condition fold into one line
naming the repositories; name the target to see each. A Claude Code session
started in this repository gets `twin status dotfiles --recorded` at session
start (`.claude/hooks/machine-context.sh`).

## Common cases

### After a push: one command

```bash
twin sync                  # in a repository's checkout or worktree: that repository; anywhere else:
                           # everything. On both machines: pull what is behind, install what moved,
                           # apply dotfiles if it moved, sync carried files; ends with the status of both
twin sync --all            # everything, from anywhere
twin sync headroom gwt     # only these targets
twin sync tools            # only the tools that belong to no repository (the pnpm pins)
twin sync --here           # only this machine
```

```text
✔ mac   headroom  pulled     3f2a1c9 → 8b7d0e4
✔ mac   headroom  installed  8b7d0e4
✔ mini  headroom  pulled     3f2a1c9 → 8b7d0e4
✔ mini  headroom  installed  8b7d0e4
· current on mac and mini: gwt
attention: none
```

`✔` is what the run changed; `✘` is what it would have done and did not,
with the reason (a pull refused, a tool not built); a dim `·` line names
what it checked and found current. Colour appears on a terminal only. Both
machines do their half at the same time, then the carried files are
reconciled.

It does the same on whichever machine it is run from, and only what is
behind: a repository that is current is not pulled, and a tool whose checkout
did not move is not rebuilt. It never forces and never switches a branch. A
main checkout that is behind and has uncommitted work, or has diverged, is
left alone and listed as `pull refused`, and a tool is not built from a
checkout holding uncommitted changes. Dotfiles is applied when its checkout
moved; a Codex source edit that was never committed waits for
`twin dotfiles apply`. It pulls main checkouts, not linked
worktrees, and it cannot move what was never pushed: that shows in the final
block as `unpublished`. The run ends with the status of what it covered, so
an empty attention block is the whole answer; `twin status <target>` lists
each item the closing block folds.

```text
exit 2, "mini: not reachable … only mac was brought up to date"
        -> this machine is done; run it again when the other is awake
both tool differs — gwt: mac built 8b7d0e4 (main), mini built 3f2a1c9 (release)
        -> the checkouts are on different branches; put them on the same one, then sync
```

The sections below are the same steps one at a time.

### A commit made here is needed there

```bash
git push                              # here
twin repos pull <target>              # there: fetch, then fast-forward only
twin repos pull                       # there, inside a linked worktree: pulls that worktree
twin repos pull planlab --both        # from either machine: pull on both, each reports for itself
pp                                    # = twin repos pull planlab planlab-handoffs --both
```

A pull refuses a dirty or diverged worktree and says why; nothing is changed.

### The pulled repository is dotfiles

```bash
twin repos pull dotfiles
twin dotfiles apply                   # restow, render ~/.codex/config.toml, re-read tmux.conf
twin dotfiles apply --load-agents     # also load this machine's launchd agents not yet loaded
```

A pull alone restows nothing. Apply is per machine and never runs for the
other one.

### The pulled repository is a tool

```bash
twin repos pull headroom
twin tools install headroom           # make install, from this machine's clone
twin tools install --all              # every tool in the manifest
twin repos pull twin && twin tools install twin   # twin itself: do it on both machines
```

Each machine calls the other's `twin` over ssh, so a `twin` change is
installed on both.

### A branch continues on the other machine

```bash
git push -u origin my-branch          # here, before leaving: a branch with no upstream does not travel
git fetch && git switch my-branch     # there
```

### A secret or env file changed

```bash
twin files sync planlab               # from either machine; the laptop does the reconciling
twin files sync --all
# or wait: the laptop's hourly tick syncs every enrolled target
```

```bash
# ~/.secrets.shared   keys both machines use; carried
# ~/.secrets          this machine's own; never carried
echo 'export NEW_API_KEY=…' >> ~/.secrets.shared     # then: twin files sync home
```

### A new repository on both machines

```toml
# twin/.config/twin/twin.toml
[repos.newproj]
path  = "~/dev/newproj"                           # must start with ~/
url   = "https://github.com/qiushiyan/newproj.git"
carry = [".env", "notes.local"]                   # gitignored paths, literal, files or directories
# branch = "main"                                 # optional: pull refuses any other branch
```

```bash
git commit -am "twin: register newproj" && git push    # in ~/dotfiles, on the machine that has it
twin repos pull dotfiles && twin dotfiles apply         # on the other machine
twin repos clone newproj                                # on the other machine
twin files enroll newproj                               # on either: lists equal / differs / one-sided
twin files enroll newproj --copy-missing                # then send the files the new clone lacks
```

### A repository gains a carried path

```toml
[repos.itell]
carry = ["apps/platform/.env", "apps/platform/.env.new"]   # added
```

```bash
# commit, push, pull and apply dotfiles on both machines first, then:
twin files enroll itell --copy-missing    # a path the enrollment does not cover blocks the target
```

### A new tool, or a new version of one

```toml
[tools.mytool]                 # built on each machine by `make install` in its clone
method = "make-install"
repo = "mytool"

[tools.obelisk]                # a pnpm global at one version on both machines
method = "pnpm-global"
package = "@obelisk-apps/cli"
version = "0.2.6-rc.0"         # upgrading is changing this pin
```

```bash
twin tools install mytool      # on each machine
twin tools install tabtype     # on the mini, after a TabType release: installs the same release
```

### A package or a launchd agent on one machine

```toml
[machines.mini]
packages = ["claude", "zsh", "newpkg"]    # the mini stows this list; the laptop the Makefile's default set
```

```bash
# a plist goes in the package of the machine that runs it; it carries that machine's home path
launchd-mac/Library/LaunchAgents/com.qiushi.thing.plist
launchd-mini/Library/LaunchAgents/com.qiushi.thing.plist
twin dotfiles apply --load-agents         # on that machine
```

### A Codex setting

```bash
$EDITOR twin/.config/twin/codex/shared.toml    # both machines
$EDITOR twin/.config/twin/codex/mini.toml      # one machine (mac.toml for the laptop)
twin dotfiles apply                            # on each: renders ~/.codex/config.toml
twin dotfiles apply --replace-codex-config     # discard a local edit that blocks the render
```

`~/.codex/config.toml` is a rendered file, never a link (§ Codex config).

### The laptop is asleep and you are on the mini

```bash
twin status                    # works; the laptop's lines are its last recorded ones
twin repos pull planlab        # works
twin tools install gwt         # works
twin files sync home           # exit 2: the laptop runs the reconciler and did not answer
```

## Carried files

A carry set is reconciled, not copied in a direction: a file changed on one
machine reaches the other, whichever it was. What cannot be decided stops
and waits.

```bash
twin files enroll <target>                    # first reconciliation: list, then reconcile
twin files enroll <target> --copy-missing     # also copy paths that exist on one machine only
twin files sync <target>                      # every later run
```

```text
· both itell: equal on both: apps/platform/.env
· both itell: differs: apps/platform/.env.local              -> needs resolving
· both itell: on mac only, held: legacy/demo/.env            -> held until resolved or --copy-missing
· both itell: same content, modes differ: … (mac 644, mini 600)  -> chmod one to match, then sync
```

### Changed on both machines, or deleted on one

Nothing is overwritten. The path is listed in every run until resolved:

```bash
twin files resolve home .planlab/.env --keep mac     # the laptop's copy wins
twin files resolve home .planlab/.env --keep mini    # the mini's copy wins
twin files resolve home .planlab/.env --delete       # remove every copy
ls ~/.local/state/twin/replaced/                     # what a resolution replaced or removed, kept here
```

`--keep` naming the machine where the file is gone is refused: use `--delete`,
or `--keep` the machine that still has it to bring it back.

### Blocked

```text
blocked — the enrollment is incomplete: a receipt or a reconciler record is missing   -> twin files enroll <target>
blocked — the manifest lists X, which the enrollment does not cover                   -> twin files enroll <target>
blocked — the two machines declare itell differently: dotfiles is at a1b2c3d on mac
          and 9f8e7d6 on mini; mini is behind                                          -> pull and apply dotfiles there
blocked — on mini, notes: holds a file git neither tracks nor ignores, notes/x.md     -> ignore or commit it
```

### What may be carried

```toml
# each line is its own example
carry = [".env"]               # ok: a literal path that git ignores
carry = [".greenflag"]         # ok: a directory; files git tracks inside it stay git's
carry = ["*.env"]              # refused: no wildcard
carry = ["README.md"]          # refused: a tracked file
carry = ["node_modules"]       # refused: build output, at any depth
[home]
carry = [".config/slack"]      # ok: paths under $HOME, outside any repository
carry = [".ssh/config"]        # refused: ~/.ssh, ~/.gnupg, ~/.secrets, gh's config, ~/.claude, ~/.codex
```

- **A pull is refused when the incoming commits add a file where a carried
  one sits.** Git treats an ignored file as expendable and would replace it.
  Move the carried file aside or drop it from the manifest, then pull.
- **A carried copy is a replica, not a backup.** An edit, a truncation
  included, reaches the other machine; only a deletion does not.
  `docs/recovery.md` owns backups.
- **The mini is not a trust boundary** (`docs/qiushi-mini.md` § Reaching the
  laptop): whatever is carried is readable by every agent session there.
- Finder's `.DS_Store` is never carried.

## The hourly tick

```bash
launchctl print gui/$(id -u)/com.qiushi.twin-tick | grep -E 'state|runs|last exit'
tail -20 ~/Library/Logs/twin-tick.log        # ends with this machine's attention block
launchctl kickstart gui/$(id -u)/com.qiushi.twin-tick    # run it now
```

```text
laptop   files sync --all, repos fetch --all, exchange observations with the mini
mini     repos fetch --all, record its observation
```

It never pulls, installs or applies, so it changes no tracked file and
nothing a running session has open.

## Codex config

```text
twin/.config/twin/codex/shared.toml     both machines
twin/.config/twin/codex/<machine>.toml  merged over it on that machine
~/.codex/config.toml                    kept from the local file: the keys in codex_runtime_tables
                                        (trust decisions, the desktop app's plugins and MCP servers)
```

Codex and its desktop app write into `~/.codex/config.toml` as they run, so
it cannot be a link into this repository. A setting changed in the local
file outside the runtime keys, a `/model` default included, is drift:

```text
mac dotfiles: codex drift — ~/.codex/config.toml was edited locally: model
```

```bash
$EDITOR twin/.config/twin/codex/shared.toml && twin dotfiles apply   # keep it: move it into the source
twin dotfiles apply --replace-codex-config                           # or discard it
```

`skill-sync` writes its generated block into the shared source, so its
changes reach Codex at the next apply.

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
  push or throwaway. Status is the reminder where the work is shared: a main
  checkout, or a branch both machines have checked out.
- **A linked worktree belongs to its machine.** The two machines never work
  in the same worktree, so a worktree's uncommitted or unpushed work is that
  machine's business; reporting it as attention buries what is shared under
  what is expected.
- **A run costs what it names.** A named status or sync inspects only those
  targets, on both machines at once, so the after-push command and the
  session-start status stay quick for one project. The record each machine
  keeps of the other stays whole, each target stamped with when it was seen.
- **Only the laptop reconciles.** One machine holds each target's lock and
  record, so a carry set is never reconciled by concurrent runs.

`twin`'s own rules and tests are in `~/dev/twin` (`CLAUDE.md`,
`internal/files/files.go`'s header). Its state is `~/.local/state/twin` on
each machine.
