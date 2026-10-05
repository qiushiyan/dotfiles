# twin: two workstations that are both worked on

Status: proposed, unbuilt. Written 2026-10-05 against dotfiles `28532cf`. Deleted when it ships; Git holds it.

## Summary

Current: `scripts/.local/bin/mini-sync`, run hourly on the laptop, makes the office mini a one-way copy of the laptop: the `~/dotfiles` tree, compiled CLIs, token files, the Codex config, TabType.
Failure: an edit made in the mini's `~/dotfiles` is overwritten by the laptop's next sync, which can be days later, and `git` history made there is replaced with the laptop's.
Failure: project repositories under `~/dev` have no mechanism at all; the mini's copies were made by hand on 2026-10-05 and will drift.

Goal: Qiushi works on either machine and picks up on the other; nothing is silently lost, and nothing unsent is silently missing.
Change: both machines hold ordinary git clones of everything, `~/dotfiles` included; git over HTTPS is the only transport for tracked content.
Change: a Go CLI, `twin`, in its own repository `~/dev/twin`, reports what is unsent on both machines, reconciles the gitignored files a manifest lists, and installs what a machine derives locally.
Change: `mini-sync`, its LaunchAgent, its Codex-config generator and the two-machine plumbing behind `pp` are deleted in the last phase.

Boundary: uncommitted work and unpushed branches do not travel; `twin` reports them.
Boundary: `twin` never commits, pushes or merges. It fetches, and fast-forwards only when asked.
Boundary: the laptop sleeps at home; from the mini, the laptop's state is its last recorded observation, never "clean".
Risk: the first reconciliation of each carried file set meets two copies that differ; those are conflicts Qiushi resolves by hand during the cutover.
Open: whether `~/.secrets` is split into a shared and a machine-local file, and which keys are shared, is Qiushi's call.

Where: § Behaviour describes the situations; § Design carries the modules, the commands and the evidence; § Delivery holds the phases and the open call.

## Intent

Vocabulary used below:

- **machine**: `mac` (the MacBook Pro, "the laptop" in the docs) or `mini` (the office Mac mini), as named by the untracked one-word `~/.config/machine` (`docs/zsh.md` § Machines). The **peer** is the other machine.
- **manifest**: one TOML file tracked in dotfiles and stowed to `~/.config/twin/twin.toml`, the only place that says what `twin` manages.
- **target**: a named manifest entry: a repository, or `home` for files outside any repository.
- **carried path**: a file or directory, gitignored or outside any repository, that the manifest lists under a target. A target's **carry set** is its carried paths.
- **reconciler**: Unison, the program that compares a carry set on the two machines against its record of their last agreement.
- **observation**: a timestamped record of one machine's repository state.
- **tool**: something a machine installs for itself from the manifest: a CLI built from its checkout, a pnpm-global package at a pinned version, a released app.

Goals:

- Either machine is a place to edit, commit and push any repository, `~/dotfiles` included.
- A carried path changed on one machine reaches the other without a direction being chosen, and a carried path changed on both is never overwritten.
- Before leaving a machine, and on sitting down at the other, one command says what is uncommitted, unpushed or out of step, on both machines, in a form an AI agent reads.
- Changing one project touches one target. Everything at once is an explicit `--all`.
- Each machine builds its own binaries and renders its own derived config; nothing compiled or generated is copied between them.

Non-goals, each with its reason:

- **Transport for uncommitted changes.** Decided: commit before switching; the report is the reminder.
- **Transport for unpushed branches** (peer-to-peer git remotes). Decided: such a branch is a forgotten push or throwaway work.
- **Automatic `git pull` or `git push`** on a timer. Decided: integration stays a deliberate act.
- **Moving a Claude Code session between machines** (`scripts/.local/bin/claude-tomini`), the clipboard tools, and `scripts/.local/bin/skill-sync`. They are not machine-to-machine state sync; `skill-sync` in particular writes into other repositories and must not run as part of activating a workstation.
- **New-machine migration.** `secrets-manifest.txt` and `scripts/list-secrets.sh` stay: they list everything a replacement machine needs, including `.ssh` and `.gnupg`, which is a different set from what two live machines share.
- **The steward's session home on the mini** (`docs/qiushi-mini.md` § Steward host). It has its own pinned checkout and binaries.
- **Version history for carried paths, and a backup destination for the mini.** Recovery from a wrong overwrite is the APFS snapshot (`docs/recovery.md`); Unison's own backup option did not write backups in two attempts and is not relied on.
- **The wiki's gitignored `sources/` originals.** Their size and their own backup ledger need a separate decision.

`twin` stands apart from `mini-sync` rather than extending it: `mini-sync` has one writer and one direction built into every step, and no step survives unchanged.

## Tenets

1. **No machine is a copy.** A design that needs one side to be authoritative for a class of state is wrong for that class, over the convenience of "the laptop wins". Held by: every transport is git or the reconciler, neither of which takes a direction (§ Design — Structure), and obligation 15.
2. **Nothing private moves unless the manifest names it.** An allowlist, over "everything ignored except artifacts": the second form copied `node_modules` the first time someone forgot an exclusion. Held by: the files module builds the reconciler's path list from the carry set and from nothing else (§ Design — Wiring), and obligations 5 and 7.
3. **A conflict or a deletion stops and reports; it never resolves itself.** A destroyed secret costs more than a manual step. Held by: the reconciler runs with deletion propagation off and without a preferred side (§ Design — Premises, Unison semantics), and obligations 2 and 3.
4. **Unknown is not clean.** A sleeping peer, a failed fetch or a branch with no upstream is reported as what it is, over a tidy row. Held by: the observation's states (§ Design — API) and obligations 8 and 9.
5. **`twin` moves state; it does not publish it.** It never commits, pushes or merges, so running it cannot put anything on GitHub or rewrite a working tree behind a session. Held by: the repos module's command set (§ Design — API) and obligation 11.

## Behaviour

### Editing dotfiles on the mini

Today: the edit works until the laptop next syncs, then is replaced by the laptop's tree without notice. `.claude/machines/mini.md` tells a session not to edit there.

After: the mini's `~/dotfiles` is a clone. The edit is committed and pushed there like any change. The mini's machine text says to pull before editing and to push before leaving.

Mechanism: the mirror step is gone (§ Design — Wiring, dotfiles). If it recurs: there is no writer left that replaces a checkout.

### Leaving one machine for the other

Today: nothing says what was left behind. The 2026-10-05 audit of the laptop found repositories with no remote, `main` ahead of its remote in six, and uncommitted edits in three.

After: `twin status` lists, for both machines, each repository with uncommitted changes, unpublished commits, or commits not yet pulled, and each carry set that is out of step, and exits non-zero when the list is not empty. Run on the mini while the laptop sleeps, the laptop's rows carry the time they were observed.

Mechanism: observations (§ Design — API). If it recurs: the same list, every run; nothing ages out of it.

### A secret file changes on one machine

Today: a token file edited on the laptop reaches the mini at the next hourly sync; one edited on the mini is overwritten.

After: the laptop's hourly run, or `twin files sync <target>` on either machine, copies the changed file to the machine where it did not change. From the mini the command asks the laptop to run the reconciliation and fails plainly when the laptop does not answer.

Mechanism: the files module (§ Design — Wiring, files). If it recurs: each change propagates once.

### The same secret file changes on both machines

Today: the laptop's copy wins silently.

After: neither copy changes. The run reports the path as a conflict and exits non-zero; every later run repeats the report. `twin files resolve <target> <path> --keep mac|mini` copies the chosen side over the other.

Mechanism: tenet 3. If it recurs: the same report until resolved.

### A carried file is deleted on one machine

Today: the deletion reaches the mini when it happens on the laptop, and is undone when it happens on the mini.

After: the other machine's copy stays, and the run reports the path as a pending deletion. `twin files resolve <target> <path> --delete` removes it from both; `--keep <machine>` restores it.

Mechanism: tenet 3. If it recurs: the same report until resolved.

### An agent runs a sync

Today: `mini-sync` prints progress lines; nothing in them says a repository on the mini holds unpushed work.

After: every `twin` command that inspects or changes state ends with an attention block: one line per item naming the machine, the target and what needs doing. The block is also printed when the command fails part-way. `--json` carries the same items. A Claude Code session started in `~/dotfiles` sees the block for the dotfiles target after its machine text.

Mechanism: the report contract (§ Design — API) and the hook (§ Design — Wiring, session start). If it recurs: the block is the last thing printed, every time.

### A tool's source moves

Today: the mini runs whatever binary the laptop last copied.

After: `twin repos pull <target>` that moves a tool's checkout adds "installed build is behind its checkout" to the attention block. `twin tools install <tool>` builds it on this machine.

Mechanism: the tools module records the revision of each successful install (§ Design — Structure). If it recurs: the item stays until the install succeeds.

## Design

`mini-sync` is a structure that blocks this design, not a base: its steps are written as "laptop does X to the mini". The build replaces it; the cutover in § Delivery is the opening reshape.

### Structure

- **Manifest and machine identity.** Owner: `twin`'s config module. Protects: every command on both machines reads one declaration, and a target name means the same thing to every command. Held by: commands receive targets from this module only (obligation 6 covers the case where the two machines hold different revisions of the manifest). Sketch: `internal/manifest`.
- **Repository observation and integration.** Owner: the repos module. Protects: tenets 4 and 5. Inspects every worktree `git worktree list` reports for a registered repository, and reports git checkouts under `~/dev` that the manifest does not register. Sketch: `internal/repos`.
- **Carried-path reconciliation.** Owner: the files module, the only caller of the reconciler. Protects: tenets 2 and 3, and that a carry set is never reconciled by two runs at once. Held by: a per-target lock taken before the reconciler starts, validation before every run, and obligations 1 to 7. Sketch: `internal/files`.
- **Local installation.** Owner: the tools module. Protects: a tool is reported current only when its last install succeeded at the checkout's present revision. Held by: the revision is written after the install command exits zero (obligation 12). Build knowledge stays in each repository's `Makefile`; the manifest names a method, not a command line. Sketch: `internal/tools`.
- **Dotfiles activation.** Owner: the dotfiles module. Protects: the directories `docs/stow-layout.md` § Directories that must stay real lists are never folded, and a machine's Codex config is never silently replaced. Held by: restowing goes through the repository `Makefile`'s `restow`, which makes those directories first, and obligation 13. Sketch: `internal/dotfiles`.
- **Where commands run.** Owner: a host seam with two adapters, local execution and `ssh <alias>`. Every module reaches the peer through it. Protects: tests exercise the real modules with two local homes. Sketch: `internal/host`.

### API

```text
twin status [target…] [--json]            # the attention block for both machines
twin repos status|fetch [target…|--all]
twin repos pull [target…|--all] [--both]  # fast-forward only; --both also on the peer
twin files status|sync [target…|--all]
twin files resolve <target> <path> --keep mac|mini | --delete
twin files resolve <target> --rebaseline
twin tools status|install [tool…|--all]
twin dotfiles apply
twin tick                                 # what the hourly LaunchAgent runs
```

Binding distinctions:

- With no target, a `repos` or `files` command acts on the repository containing the working directory, and fails when there is none. Every registered target needs `--all`.
- `repos pull` refuses a worktree that has uncommitted changes or has diverged from its upstream; it never touches a carried path.
- `files sync` never runs `git`. A target with an empty carry set does not start the reconciler.
- Exit status: 0 when nothing needs attention; 1 when the command completed and the attention block is not empty; 2 when it failed or could not determine an answer.
- The attention block states, per item: the machine, the target, the condition, and the command or manual act that clears it. It does not say a state is fine by omission when the state is unknown: unknown items are listed.

An observation of one repository on one machine, per worktree:

| state | entered when | left when | written by |
| --- | --- | --- | --- |
| uncommitted | the worktree has modified, staged or untracked-unignored files | they are committed or discarded | the repos module on that machine |
| unpublished | a branch is ahead of its upstream; or has no upstream and is checked out in a worktree or has a commit in the last 14 days | pushed, or the branch is deleted | the same |
| behind | the upstream ref from the last successful fetch is ahead of the branch | pulled | the same |
| fetch-unknown | no fetch has succeeded, or the last one failed | a fetch succeeds | the same |
| in step | none of the above | any of the above | the same |

A peer's observation as seen from this machine is `live` (the peer answered now), `recorded at <time>` (read from the store on the mini), or `none`. Only `live` and `recorded` rows are shown as states; `none` is an attention item.

A carry set, per target:

| state | entered when | left when | written by |
| --- | --- | --- | --- |
| not enrolled | the target has never been reconciled | the first reconciliation completes | the files module on the laptop |
| in step | a reconciliation completed with nothing skipped | a carried path changes | the same |
| needs resolving | a path changed on both machines, or was deleted on one | `files resolve` for each such path | the same |
| blocked | validation failed, the two machines' declarations of the target differ, or the reconciler's record is missing for an enrolled target | the cause is fixed; a missing record needs `files resolve --rebaseline` | the same |
| unknown | the peer did not answer | a run reaches the peer | the same |

Walking the real inputs: `itell`'s `.env` files exist on both machines with equal content, so enrollment records agreement and the set is in step. `~/.secrets` differs between the machines today, so its enrollment is `needs resolving` (see § Delivery). The planlab checkout's env files are copies; equal, in step.

### Wiring

Dotfiles.

- Today: `mini-sync` rsyncs the laptop's tree, `.git` included, over the mini's with `--delete` (`scripts/.local/bin/mini-sync`, the `rsync -a --delete --copy-unsafe-links` line), then runs `make -s -C ~/dotfiles restow PACKAGES=…` there for a subset of packages.
- Today: skills owned by other projects are symlinks out of the tree; five are absolute paths under `/Users/qiushi` (`claude/.claude/skills/{read-email,write-email,slack,explain-diff,terminal-browser}`), which do not resolve under the mini's home `/Users/qiushiyan`. The mirror hides this by copying their targets as directories; in the mini's checkout they show as deletions of the tracked links.
- Today: `~/.gitconfig` on the mini is its own file; the `git` package is not stowed there.
- After: both machines clone `https://github.com/qiushiyan/dotfiles.git`. The manifest lists each machine's stow packages. `twin dotfiles apply` restows them through the `Makefile`, renders the Codex config, loads that machine's launchd agents, and re-sources the tmux config in a running server when `tmux.conf` changed since the last apply.
- After: the out-of-tree skill links are relative, as `greenflag-concierge` already is, and the Makefile targets that create them in `~/dev/slackkit` and `~/dev/mailkit` write relative links. `terminal-browser` links into an app directory the mini does not have; see Premises.
- After: launchd agents move out of the `scripts` package into per-machine packages, so that stowing `scripts` on the mini does not place the laptop's agents (`scripts/Library/LaunchAgents/`) where launchd loads them at login. Sketch: `launchd-mac/`, `launchd-mini/`, and a shared one for the `twin tick` agent.
- After: the `git` package is stowed on both machines; `~/.gitconfig.personal` is a carried path of `home`.

Codex config.

- Today: on the laptop `~/.codex/config.toml` is a symlink to the tracked `codex/.codex/config.toml`, so Codex's runtime writes (project trust) keep that file modified. On the mini the file is generated from the laptop's by `scripts/.local/share/dotfiles/mini-codex-config.py`, which keeps three runtime-owned tables from the mini's copy and reverts every other local change.
- After: the tracked file holds shared settings only and is not stowed. Each machine's `~/.codex/config.toml` is a real file rendered by `twin dotfiles apply` from the tracked file, minus the tables the manifest marks as belonging to the other machine, plus the runtime-owned tables kept from the local file. When the local file differs from the last render outside the runtime-owned tables, the render stops and reports the differing keys; the change is either moved into the tracked file or discarded with an explicit flag. A permanently modified tracked file would otherwise make the dotfiles target report "uncommitted" forever.

Files.

- Today: `mini-sync` copies the paths in its `SECRETS` array to the mini with `rsync -aR` on every run, laptop to mini only.
- After: the laptop runs the reconciler, one run per target: roots are the target's directory on each machine (`$HOME` for `home`), restricted to the carry set, with deletion propagation off on both roots, no preferred side, and the reconciler's record kept in a `twin`-owned state directory on each machine, outside every carried path. The mini's `twin files sync` executes the same command on the laptop through the host seam. Failure of the peer or the reconciler goes to exit status 2 and the attention block; nothing is retried in the run.
- After, before every run: each carried path is checked on both machines. A path that git tracks in that checkout, that resolves outside its root, that is on the manifest's never list, or that contains a directory named as a build artifact (`node_modules`, `.next`, `.turbo`, `dist`, `build`, `target`, `.venv`, `__pycache__`) blocks the target. Carried paths belong to a repository's main checkout; linked worktrees are seeded by `gwt`, as now.
- After, before every run: the laptop compares a digest of its declaration of the target with the mini's. A difference blocks the target and names the machine whose dotfiles are behind.

Repositories.

- Today: `pp` (`zsh/.config/zsh/nav.zsh`) pulls the planlab checkout and its briefs clone on both machines through `_pull_both`, an ssh fan-out of its own.
- After: `pp` is `twin repos pull` for those two targets with `--both`, keeping its `--cd`. The fan-out helper is deleted.
- After: `twin tick` on each machine fetches every registered repository and records that machine's observation; the laptop also publishes its observation to the store on the mini and reconciles every enrolled carry set.

Session start.

- Today: `.claude/hooks/machine-context.sh` prints `.claude/machines/<name>.md`.
- After: the hook also prints `twin status dotfiles` from recorded observations only, with no network call and a short timeout, and prints the machine text alone when `twin` is absent.

Tools.

- Today: `mini-sync` copies the binaries in `BINS` from the laptop's `~/.local/bin`, copies `/Applications/TabType.app`, and matches the pnpm-global packages in `ENGINES` to the laptop's versions.
- After: `twin tools install` runs the method the manifest names: `make install` in the checkout; a pnpm-global package at the version the manifest pins; or the checkout's own release installer (TabType's `~/dev/tabtype/scripts/install-release.sh`, which verifies the signature before replacing the app). The slack-digest agents on the mini are installed there by a local target in `~/dev/slackkit`, replacing its laptop-driven `install-mini`.

### Design it twice

- **Winner: resource modules behind a small command set, with the reconciler borrowed.** Constraint optimised: each kind of state has one owner whose failure modes it alone handles.
- **Rejected: three generic verbs (`status`, `sync`, `apply`) over a recipe manifest with a hand-written three-way file sync.** Optimised for few entry points. Lost because a target name meant a different thing to each verb, `sync` joined two jobs that fail differently, and the hand-written record of "last agreement" left enrollment, deletion and loss of the record undefined. The manifest must not carry command lines for the same reason.
- **Rejected: every copy names its source.** Optimised for explicit authority. Lost because every ordinary one-sided edit would need a direction chosen by hand; it contradicts tenet 1.
- **Rejected: one "ready to leave" operation that reconciles, installs and reports.** Optimised for a single habit. Lost because it hides local installation inside a handoff step; its reporting half survives as `twin status`.

### Premises

Decision: Unison is the reconciler, run in batch mode with `-nodeletion` on both roots and `-confirmbigdel=false`. Settled.
Basis: measured, 2026-10-05, Unison 2.54.0 from Homebrew on both machines, scratch roots.
Ran: two local roots restricted with `-path`; then the laptop against `ssh://qiushi-mini/…` with `-servercmd "env UNISON=<dir> UNISONLOCALHOSTNAME=mini /opt/homebrew/bin/unison"`.
Result:

- a file on one side only is copied, and a path outside the `-path` list is never copied;
- a one-sided change propagates and keeps mode 600;
- a two-sided change is skipped with both copies intact, exit 1, and is skipped again on rerun;
- a deletion with the other side unchanged is skipped ("would delete a file with nodeletion"), exit 1, while other paths in the same run still propagate; a deletion against an edit is skipped;
- a second concurrent run fails on the lock, exit 3; with one side's record deleted the run refuses, exit 3;
- a run killed during a 600 MB transfer left the destination at its old content, and the rerun converged;
- a no-op run over ssh took 0.56 s; the laptop's build is OCaml 5.4.1 and the mini's 5.5.0, and they interoperate.

Establishes: tenet 3's mechanism, the conflict and deletion states, and that the record can live in a `twin`-owned directory on both machines.
Does not establish: behaviour with a carried directory that gains files on both sides at once; the kill was timed by hand, once.

Decision: an enrolled target whose reconciler record is missing is blocked until `files resolve --rebaseline`. Settled.
Basis: measured, same session: with both records deleted, Unison treats the next run as a first run, so a file deleted on one machine before the loss was copied back. `twin` therefore records enrollment itself and refuses the run when its record says enrolled and the reconciler's record is absent.

Decision: `UNISONLOCALHOSTNAME` is set to the machine name for both ends. Settled.
Basis: established from source and observed: the mini reports the DHCP name `Mac.lan` (`docs/zsh.md` § Machines), and Unison names its record after the host name.

Decision: personal CLIs are built on each machine. Settled.
Basis: measured, 2026-10-05, on the mini: `go build ./...` succeeded in the clones of `headroom`, `envoy`, `brief`, `gwt`, `gopen`, `cout`, `slackkit` (two binaries), `claude-steps` and `degit`; all but `degit` have a `make install` target. Does not establish that each `make install` runs clean there, which the cutover exercises.

Decision: git runs over HTTPS on both machines, including when driven over ssh. Settled.
Basis: measured, 2026-10-05: with the laptop's `gh` token in its keyring, `git` on the laptop failed from an ssh session (`could not read Username for 'https://github.com'`); with the token in `~/.config/gh/hosts.yml`, as on the mini, `pp` run on the mini completed on both machines (`docs/qiushi-mini.md` § Reaching the laptop).

Decision: a branch with no upstream counts as unpublished when it is checked out in a worktree or has a commit in the last 14 days. Proposed.
Basis: assumed, from the 2026-10-05 audit, where most upstream-less branches in team repositories were merged work whose remote branch had been deleted.
Fallback: the window is one manifest value; a noisy or silent report changes the number, not the states.

Decision: the `terminal-browser` skill link may dangle on the mini. Proposed.
Basis: assumed: Claude Code skips a skill whose link does not resolve.
Outstanding verification: start a session on the mini after the cutover and read its skill list.
Fallback: install terminal-browser on the mini, or drop the link from the mini's packages by moving it to a laptop-only package.

## Verification

The build reports each obligation below by number: pinned, a test that goes red when the behaviour is removed; nominal, a test that exists but would stay green; or skipped, with the reason.

Unless stated otherwise: observed through `twin`'s commands, in Go tests, with two temporary homes behind the local host adapter, real `git` and the real Unison binary. Both are installed on both machines. The ssh adapter is exercised only in obligations 15 and 16.

1. A carried path changed in one home is equal in both after `files sync`, with its mode kept.
2. A carried path changed in both homes is unchanged in both after `files sync`; the attention block names it; exit status is 1; a second run reports it again.
3. A carried path deleted in one home is still present in the other after `files sync` and is reported; `files resolve --delete` removes both; `--keep` restores it.
4. With the reconciler's record removed from an enrolled target, `files sync` changes no file and reports the target blocked; `files resolve --rebaseline` lists the paths present on one side only before doing anything.
5. A carry set naming a git-tracked path, a path that escapes its root through a symlink, a never-listed path, or a directory containing `node_modules` is refused before the reconciler starts. Fixture: a repository where the path is ignored on `main` and tracked on another worktree's branch.
6. With the two homes holding different declarations of one target, `files sync` changes no file and names the machine that is behind.
7. A target with an empty carry set starts no reconciler process.
8. `repos status` reports uncommitted, unpublished and behind for the main checkout and for a linked worktree; a repository that has never fetched, or whose remote is unreachable, is `fetch-unknown`, not in step.
9. With the peer adapter failing, the peer's rows show the recorded observation and its time, or an attention item when there is none.
10. A command made to fail after its first target still prints the attention block and the same items under `--json`.
11. `repos pull` fast-forwards a clean worktree; refuses a dirty or diverged one; changes no carried path. No `twin` command creates a commit or a push: asserted over the fixture remotes' reflogs across the suite.
12. A failing install leaves the tool reported as behind; a succeeding one records the checkout's revision.
13. `dotfiles apply` in a temporary home leaves `~/.claude` and `~/.codex` real directories; the rendered Codex config keeps the runtime-owned tables and omits the other machine's tables; a local edit outside those tables stops the render. The existing guard `zsh/.config/zsh/tests/stow-reach.test.zsh` stays green.
14. The session-start hook prints the machine text and the dotfiles items from recorded observations with the network unavailable, and the machine text alone with no `twin` on `PATH`. Extends `.claude/hooks/test-machine-context.sh`.
15. Live, after the cutover: a commit made in the mini's `~/dotfiles` is still at its `HEAD` after the laptop's next `twin tick`. Manual, once; it is the observation that `mini-sync` is gone.
16. Live, after the cutover: `twin files sync home` from the mini, with the laptop awake and then asleep. Manual; the second run must exit 2 and name the laptop as unreachable.

Limit: the fixtures cannot show the reconciler's behaviour between two OCaml builds or over a dropped tailnet link; the first was measured once (§ Design — Premises).

## Delivery

Boundary: two repositories. `twin` is new and lives in `~/dev/twin` (`github.com/qiushiyan/twin`, private), because it is a tool with its own tests and release, like `headroom` and `gwt`. The dotfiles changes land on `main` as the phases below, in order, because phase 3 is an operational step on two live machines and the old writer must be stopped before it.

1. **Build `twin`** against fixtures: obligations 1 to 14.
2. **Prepare dotfiles**, with `mini-sync` still running and behaviour unchanged: the manifest; relative skill links; per-machine launchd packages; the tracked Codex file reduced to shared settings with the laptop rendering its own; the machine texts drafted. Each change is correct under the mirror, since the mirror copies it.
3. **Cut over**, with both machines awake:
   1. Unload the `com.qiushi.mini-sync` LaunchAgent on the laptop. Nothing else proceeds until it is gone.
   2. Take an APFS snapshot on both (`snapshot`).
   3. On the mini: bring `~/dotfiles` to a clean checkout of `origin/main` (the copied skill directories give way to the tracked links), move the hand-written `~/.gitconfig` aside, and run `twin dotfiles apply`.
   4. On both: `twin tools install --all`.
   5. Enroll each carry set; resolve the conflicts that enrollment reports.
   6. Load the `twin tick` agent on both. Obligations 15 and 16.
4. **Clean up the old sync family in dotfiles**: delete `scripts/.local/bin/mini-sync`, `scripts/Library/LaunchAgents/com.qiushi.mini-sync.plist`, `scripts/.local/share/dotfiles/mini-codex-config.py` and `_pull_both`; rewrite `pp`; replace the mirror rules in `.claude/machines/`, `CLAUDE.md` and `docs/qiushi-mini.md` § Sync and § Personal checkouts; change step 8 of `~/dev/tabtype/docs/releasing.md` to the tools command. `claude-tomini`, `tomini`, `frommini`, `skill-sync`, `secrets-manifest.txt` and `scripts/list-secrets.sh` stay (§ Intent, non-goals).

Phases 1 and 2 fit one session; 3 and 4 a second, with a handoff between.

Open:

Choice: split `~/.secrets` into a machine-local `~/.secrets` and a carried `~/.secrets.shared`, both sourced by `zsh/.zshrc`, or carry `~/.secrets` whole.
Consequence: split, the mini holds only the keys placed in the shared file, and a key's reach is decided by which file it is written in. Whole, every key on the laptop is readable by the permission-bypassed agent sessions and the steward's sessions that run under the same user on the mini (`docs/qiushi-mini.md` § Steward host), reversing the present arrangement in which the mini's file holds one line.
Recommendation: split, with the shared file starting from what the mini uses today.
Decides: Qiushi.
Waits on it: the `home` carry set's entry for secrets and its enrollment in phase 3. Everything else proceeds.
