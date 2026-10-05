# twin: two workstations that are both worked on

Status: shipped 2026-10-05; both machines run on it. § As built, at the end, says what the build changed and how each obligation stands. The live docs still describe the mirror until the `/update-docs` pass folds this in; this file is deleted then, and Git holds it.

## Summary

Current: `scripts/.local/bin/mini-sync`, run hourly on the laptop, makes the office mini a one-way copy of the laptop: the `~/dotfiles` tree, compiled CLIs, token files, the Codex config, TabType.
Failure: an edit made in the mini's `~/dotfiles` is overwritten by the laptop's next sync, which can be days later, and `git` history made there is replaced with the laptop's.
Failure: project repositories under `~/dev` have no mechanism at all; the mini's copies were made by hand on 2026-10-05 and will drift.

Goal: Qiushi works on either machine and picks up on the other; nothing is silently lost, and nothing unsent is silently missing.
Change: both machines hold ordinary git clones of everything, `~/dotfiles` included; git over HTTPS is the only transport for tracked content.
Change: a Go CLI, `twin`, in its own repository `~/dev/twin`, reports what is unsent on both machines, reconciles the gitignored files a manifest lists through Unison, installs what a machine builds for itself, and activates dotfiles on that machine.
Change: an hourly `twin tick` on each machine fetches and records state; the laptop's also reconciles carried files.
Change: dotfiles gains one launchd package per machine, relative skill links, and a Codex config that each machine renders for itself.
Change: `mini-sync`, its LaunchAgent, its Codex-config generator and the two-machine plumbing behind `pp` are removed.

Boundary: uncommitted work and unpushed branches do not travel; `twin` reports them.
Boundary: `twin` never commits, pushes or merges, and changes tracked files only on an explicit `repos pull` or `repos clone`.
Boundary: only the laptop runs the reconciler, so carried files move only while the laptop is awake; when the laptop does not answer, the mini shows its last recorded observation, never "clean".
Boundary: a deletion or a two-sided change of a carried file never propagates; it waits for an explicit resolution.
Boundary: the theme no longer follows the laptop; each machine keeps its own.
Depends: Unison 2.54 from Homebrew on both machines, installed 2026-10-05.
Change: `~/.secrets` splits in two: `~/.secrets.shared` is carried, `~/.secrets` stays on its machine.
Risk: enrollment, the explicit first reconciliation of each carry set, meets copies that differ or exist on one machine only; Qiushi resolves those by hand during the cutover.
Settled in the build: terminal-browser's skill link is untracked, each machine keeping its own (§ Design — Premises).

Where: § Behaviour describes the situations; § Design carries the manifest, the modules, the commands and the evidence; § Delivery holds the phases.

## Intent

Vocabulary used below:

- **machine**: `mac` (the MacBook Pro, "the laptop" in the docs) or `mini` (the office Mac mini), as named by the untracked one-word `~/.config/machine` (`docs/zsh.md` § Machines). The **peer** is the other machine.
- **manifest**: one TOML file tracked in dotfiles and stowed to `~/.config/twin/twin.toml`, the only place that says what `twin` manages (§ Design — Manifest).
- **target**: a named manifest entry: a repository, or `home` for files outside any repository.
- **carried path**: a file or directory, gitignored or outside any repository, that the manifest lists under a target, as a literal path with no wildcard. A target's **carry set** is its carried paths.
- **reconciler**: Unison, the program that compares a carry set on the two machines against its **record** of their last agreement.
- **enrollment**: the first reconciliation of a target, started by an explicit command, after which `twin` holds an **enrollment receipt** for the target on both machines. The receipt lists the carried paths it covers and the paths it **holds**: carried paths kept out of the reconciler's runs until resolved.
- **observation**: a timestamped record of one machine's state: its repositories, its tools and its dotfiles activation. Each machine keeps its own latest observation and the latest it has received from the peer.
- **tool**: something a machine installs for itself from the manifest: a CLI built from its checkout, a pnpm-global package at a pinned version, a released app.
- **attention item**: one thing a person must act on, as § Design — API defines; **informational** lines are shown but are not attention items.

Goals:

- Either machine is a place to edit, commit and push any repository, `~/dotfiles` included.
- A carried path changed on one machine reaches the other without a direction being chosen, and a carried path changed on both is never overwritten.
- Before leaving a machine, and on sitting down at the other, one command says what is uncommitted, unpublished or out of step, on both machines, in a form an AI agent reads.
- Changing one project touches one target. A command that changes state acts on every target only with an explicit `--all`.
- Each machine builds its own binaries and renders its own derived config; nothing compiled or generated is copied between them.

Non-goals, each with its reason:

- **Transport for uncommitted changes.** Decided: commit before switching; the report is the reminder.
- **Transport for unpushed branches** (peer-to-peer git remotes). Decided: such a branch is a forgotten push or throwaway work.
- **Automatic `git pull` or `git push`** on a timer. Decided: integration stays a deliberate act.
- **Moving a Claude Code session between machines** (`scripts/.local/bin/claude-tomini`), the clipboard tools, and `scripts/.local/bin/skill-sync`. They are not machine-to-machine state sync; `skill-sync` writes into other repositories and must not run as part of activating a workstation.
- **New-machine migration.** `secrets-manifest.txt` and `scripts/list-secrets.sh` stay: they list everything a replacement machine needs, including `.ssh` and `.gnupg`, which is a different set from what two live machines share.
- **The steward's session home on the mini** (`docs/qiushi-mini.md` § Steward host). It has its own pinned checkout and binaries.
- **Theme following.** `mini-sync` applies the laptop's theme to the mini when the laptop switches. With two primary machines a theme is each machine's own preference, set with `prefix t`; nothing replaces the step.
- **Version history for carried paths.** An ordinary propagation overwrites only a copy the reconciler recorded as equal to the other machine's at their last agreement, so the content replaced is the version the edit superseded. The nets are the daily APFS snapshot (`docs/recovery.md` § Local snapshots), which this work also schedules on the mini, and the copy `files resolve` sets aside before it replaces or removes one (§ Design — API). Unison's own backup option wrote no backups in two attempts and is not used.
- **The wiki's gitignored `sources/` originals.** Their size and their own backup ledger need a separate decision.

`twin` stands apart from `mini-sync` rather than extending it: `mini-sync` has one writer and one direction built into every step, and no step survives unchanged.

## Tenets

1. **No machine is a copy.** A design that needs one side to be authoritative for a class of state is wrong for that class, over the convenience of "the laptop wins". Held by: every transport is git or the reconciler, neither of which takes a direction (§ Design — Structure), and obligation 17.
2. **Nothing private moves unless the manifest names it.** An allowlist, over "everything ignored except artifacts": the second form copies `node_modules` the first time an exclusion is forgotten. Held by: the files module builds the reconciler's path list from the carry set and from nothing else (§ Design — Wiring, files), and obligations 5 and 7.
3. **A conflict or a deletion stops and reports; it never resolves itself.** A destroyed secret costs more than a manual step. Held by: the reconciler runs with deletion propagation off and without a preferred side (§ Design — Premises), and obligations 2 and 3.
4. **Unknown is not clean.** A sleeping peer, a failed fetch or a missing record is reported as what it is, over a tidy row. Held by: the conditions and states in § Design — API, and obligations 8 and 9.
5. **No tracked file changes unless asked.** `twin` never commits, pushes or merges, and updates tracked files in a working tree only inside `repos pull` and `repos clone`. A timer moves carried paths and nothing else, so it cannot rewrite code behind a running session or put anything on GitHub. Held by: the command set (§ Design — API) and obligation 11.

## Behaviour

### Editing dotfiles on the mini

Today: the edit works until the laptop next syncs, then is replaced by the laptop's tree without notice. `.claude/machines/mini.md` tells a session not to edit there.

After: the mini's `~/dotfiles` is a clone. The edit is committed and pushed there like any change. The mini's machine text says that the checkout is a clone, to pull first when `twin status` shows it behind, and that a commit is not on the other machine until it is pushed. Pushing stays Qiushi's call, as `CLAUDE.md` § Working here has it.

Mechanism: the mirror step is gone (§ Design — Wiring, dotfiles). If it recurs: there is no writer left that replaces a checkout.

### Leaving one machine for the other

Today: nothing says what was left behind. A scan of the laptop on 2026-10-05 found repositories with no remote, `main` ahead of its remote in six, and uncommitted edits in three.

After: `twin status` lists the attention items of both machines and exits 1 when there are any. Run on the mini while the laptop sleeps, the laptop's items carry the time they were observed, and "laptop not reachable" is itself an item.

Mechanism: observations (§ Design — API). If it recurs: the same list, every run; no attention item ages out.

### A secret file changes on one machine

Today: a token file edited on the laptop reaches the mini at the next hourly sync; one edited on the mini is overwritten.

After: the laptop's hourly run, or `twin files sync <target>` on either machine, copies the changed file to the machine where it did not change. From the mini the command asks the laptop to run the reconciliation, and exits 2 naming the laptop when it does not answer.

Mechanism: the files module (§ Design — Wiring, files). If it recurs: each change propagates once.

### The same secret file changes on both machines

Today: the laptop's copy wins silently.

After: neither copy changes. The run lists the path as needing resolution and exits 1; every later run lists it again. `twin files resolve <target> <path> --keep mac` (or `mini`) replaces the other machine's copy with the named machine's.

Mechanism: tenet 3. If it recurs: the same item until resolved.

### A carried file is deleted on one machine

Today: the deletion reaches the mini when it happens on the laptop, and is undone when it happens on the mini.

After: the other machine's copy stays, and the run lists the path as needing resolution. `twin files resolve <target> <path> --delete` removes it from both machines. `--keep <machine>`, naming the machine that still has the file, copies it back; naming the machine where it is gone is refused with a pointer to `--delete`.

Mechanism: tenet 3. If it recurs: the same item until resolved.

### An agent runs a sync

Today: `mini-sync` prints progress lines; nothing in them says a repository on the mini holds unpushed work.

After: every `twin` command ends with the attention block (§ Design — API), including when it fails part-way. `--json` carries the same items. A Claude Code session started in `~/dotfiles` sees the dotfiles target's items after its machine text.

Mechanism: the report contract (§ Design — API) and the hook (§ Design — Wiring, session start). If it recurs: the block is the last thing printed, every time.

### A tool's source or the dotfiles checkout moves

Today: the mini runs whatever binary the laptop last copied, and the laptop's sync restows the mini's links.

After: a `twin repos pull` that moves a tool's checkout, or the dotfiles checkout, adds an attention item: the installed build is behind its checkout, or dotfiles activation is behind its checkout. `twin tools install <tool>` and `twin dotfiles apply` clear them. Neither runs implicitly.

Mechanism: receipts (§ Design — Structure, local installation and dotfiles activation). If it recurs: the item stays until the command succeeds.

### A repository exists on one machine only

Today: it is cloned by hand, and its gitignored files copied by hand.

After: a `status` command lists it as absent on the other machine. There, `twin repos clone <target>` clones it from the manifest's URL, and `twin files enroll <target> --copy-missing` brings its carried files.

Mechanism: § Design — API. If it recurs: the item stays until the clone exists.

## Design

`mini-sync` is a structure that blocks this design, not a base: its steps are written as "the laptop does X to the mini". `twin` replaces it at the cutover (§ Delivery, phase 3).

### Manifest

The manifest is the whole declaration; nothing about what `twin` manages is compiled in except the protected paths below. Its schema, as built (`twin/.config/twin/twin.toml` is the real one):

```toml
reconciles = "mac"               # the one machine that runs the reconciler

[machines.mac]
ssh = "mac"                      # the alias the peer uses to reach this machine
                                 # no packages: the Makefile's default set
[machines.mini]
ssh = "mini"
packages = ["claude", "zsh"]     # a literal stow list

[dotfiles]
repo = "dotfiles"                # the target that is the dotfiles checkout
codex_runtime_tables = ["projects", "hooks.state", "notify"]   # what Codex and its desktop app write

[home]
carry = [".gitconfig.personal", ".config/slack"]

[repos.itell]
path   = "~/dev/itell"           # must start with ~/, the same place under either home
url    = "https://github.com/learlab/itell.git"
carry  = ["apps/platform/.env"]  # literal paths, files or directories
branch = "main"                  # optional: pull refuses any other branch

[tools.headroom]
method = "make-install"
repo = "headroom"
[tools.obelisk]
method = "pnpm-global"
package = "@obelisk-apps/cli"
version = "0.2.6-rc.0"
[tools.tabtype]
method = "release-installer"
repo = "tabtype"
script = "scripts/install-release.sh"
app = "TabType"
```

An unknown key fails the load. The Codex source sits beside the manifest, in `codex/{shared,mac,mini}.toml`.

Initial contents, confirmed against both disks on 2026-10-05:

- **Repositories:** `dotfiles`, `wiki`, `twin`, `planlab` (`~/dev/planlab/main`), `planlab-handoffs` (`~/dev/.handoffs/planlab-main`, `branch = "main"`), `itell`, `itell-cms`, and the personal tools cloned to the mini on 2026-10-05: `brief`, `ccclean`, `claude-steps`, `cout`, `degit`, `envoy`, `explain-diff`, `gopen`, `greenflag`, `gwt`, `headroom`, `jev-openrouter-gallery`, `mailkit`, `raycast-tab-utils`, `slackkit`, `tabtype`.
- **Carry sets:** `itell`, its seven ignored env files, and `itell-cms`, its two; `planlab`, its two local env files, `~/dev/planlab/main/application/.env.development.local` and `~/dev/planlab/main/application/tests/e2e/loopy-stress/.env.smoke.local`; `jev-openrouter-gallery`, `.env`; `greenflag`, `.greenflag`, a directory of ignored working documents beside two files git tracks; `explain-diff`, `resources`; `tabtype`, `HANDOFF.md`, `screenshots.local`, `espanso-docs`. `HANDOFF.md` is ignored through the clone's own `.git/info/exclude`, which each machine holds for itself. `home`: `mini-sync`'s `SECRETS` paths (`~/.planlab/.env`, `~/.bench/.env`, `~/.config/slack`, `~/.config/slack-digest`), `~/.gitconfig.personal`, `~/.config/planlab/dev.json`, `~/.aws/config`, and `~/.secrets.shared`. None of the `home` paths contains either machine's home path (scanned on both, 2026-10-05); one that came to would stay machine-specific and leave the carry set.
- **Tools:** `make-install` for `headroom`, `envoy`, `brief`, `gwt`, `gopen`, `cout`, `claude-steps`, `slackkit` and `twin`; `pnpm-global` for `@obelisk-apps/cli` at the laptop's version on 2026-10-05, `0.2.6-rc.0`; `release-installer` for TabType.
- **Stow packages:** the laptop, `"all"`: whatever the `Makefile`'s default set is, which excludes the other machine's launchd package (§ Wiring, dotfiles). The mini, a list: `mini-sync`'s `STOW` array (`claude claude-steps ghostty gwt karabiner lessons nvim ohmyposh tabtype tmux zsh`) plus `git`, `scripts`, `codex`, the new `twin` package and its machine package.

Protected paths, compiled into `twin` and never carriable whatever the manifest says. Under `home`, as prefixes relative to `$HOME`: `.ssh`, `.gnupg`, `.secrets`, `.config/gh`, `.config/machine`, `.claude`, `.codex`, `Library/Keychains`, and `twin`'s state directory, `~/.local/state/twin`. Under a repository: its `.git`.

Secrets, decided by Qiushi on 2026-10-05: `zsh/.zshrc` sources `~/.secrets.shared` and then `~/.secrets`. The shared file holds `CONTEXT7_API_KEY`, `OPENROUTER_API_KEY`, `POSTHOG_MCP_API_KEY`, `SLACK_APP_TOKEN`, `SLACK_BOT_TOKEN` and `OP_ACCOUNT`; `STEAM_API_KEY_1` stays in the laptop's `~/.secrets`. A key's reach is decided by the file it is written in, so the agent sessions on the mini read only what was placed in the shared file.

The pnpm pin is owned here; the laptop-only upgrade note in the obelisk skill's `PINNED.txt` gives way to it.

### Structure

- **Manifest and machine identity.** Owner: `twin`'s manifest module. Protects: every command on both machines reads one declaration, and a target name means the same thing to every command. Held by: commands receive targets from this module only; obligation 6 covers two machines holding different revisions. Sketch: `internal/manifest`.
- **Repository observation and integration.** Owner: the repos module. Protects: tenets 4 and 5, and that a pull never replaces a carried path. Held by: the collision check in § Wiring, repositories, and obligations 8 and 11. Sketch: `internal/repos`.
- **Carried-path reconciliation.** Owner: the files module, the only caller of the reconciler. Protects: tenets 2 and 3; a carry set is never reconciled by two runs at once; a target is never initialised by an ordinary sync. Held by: a per-target lock taken before the reconciler starts, validation before every run, the enrollment receipt, and obligations 1 to 7. Sketch: `internal/files`.
- **Local installation.** Owner: the tools module. Protects: a tool is reported current only when what is installed matches what the manifest and the checkout call for. Held by: a receipt per method, written after the install command exits zero (§ API, receipts; obligation 12). Build knowledge stays in each repository's `Makefile` or installer; the manifest names a method, never a command line. Sketch: `internal/tools`.
- **Dotfiles activation.** Owner: the dotfiles module. Protects: the directories `docs/stow-layout.md` § Directories that must stay real lists are never folded; a machine never stows another machine's package; a machine's Codex config is never silently replaced. Held by: restowing goes through the repository `Makefile`, the drift check in § Wiring, Codex config, and obligation 13. Sketch: `internal/dotfiles`.
- **Where commands run.** Owner: a host seam with two adapters, local execution and `ssh <alias>`. It gives a module two things for a machine: a way to run a command there, and the reconciler root for a path there (a local path, or `ssh://<alias>/<path>` with the remote command that sets the reconciler's state directory and host name). Protects: tests exercise the real modules with two local homes. Remote commands run non-interactively with a time limit (`BatchMode`, `GIT_TERMINAL_PROMPT=0`). Sketch: `internal/host`.

### API

```text
twin status [target…] [--recorded]
twin observe
twin repos status|fetch [target…|--all]
twin repos pull  [target…|--all] [--both]
twin repos clone <target>
twin files status [target…|--all]
twin files enroll <target> [--copy-missing]
twin files sync  [target…|--all]
twin files resolve <target> <path> --keep mac|mini | --delete
twin tools status|install [tool…|--all]
twin dotfiles apply [--load-agents] [--replace-codex-config]
twin tick
```

Every command accepts `--json`.

Binding distinctions:

- **Target selection.** A named repository target means the main checkout at the manifest's `path`. With no target, a `repos` command acts on the worktree that contains the working directory, main or linked, and a `files` command on that repository's main checkout; both fail outside a registered repository. `--all` is every registered target. The status commands are the exception: with no target they cover everything, because they change nothing. `tools install` needs tool names or `--all`.
- **Status commands** (`twin status`, `repos status`, `files status`, `tools status`) report both machines. None of them fetches: "behind" is as of the last fetch, whose time is shown. Each asks the peer for a live observation (`twin observe` over the host seam) and falls back to the last one received. `--recorded` skips that call. Every item has a target: a tool's items belong to its `repo`, or to the pseudo-target `tools` when it has none, and dotfiles activation, Codex drift and agents not loaded belong to `dotfiles`. `twin status <target>` shows the named targets' items, plus a missing or unreachable peer. A status command inspects the whole machine each time, records the observation, and filters only what it prints.
- **`twin observe`** inspects this machine, records its observation and prints it. It is what `tick` runs and what the peer is asked for. An observation holds, per repository, the conditions below for every worktree; per tool, its receipt; the dotfiles activation receipt; the launchd agents of this machine's package that are not loaded; and, on the laptop, the carry-set states.
- **Other commands** print the items of the targets they acted on, for the machines they acted on, and exit by those items. Only status commands, `--both` and the `files` commands contact the peer.
- **`repos pull`** fetches, then re-reads the worktree; it refuses a worktree with uncommitted changes, one that has diverged from its upstream, one on a branch other than the manifest's `branch` when that is set, and one where the incoming commits add a path that collides with a carried path (§ Wiring, repositories). A refusal is an attention item, "pull refused", with its reason. Otherwise it fast-forwards. With `--both`, which needs named targets, it also runs on the peer and reports each machine's result separately; one machine's refusal does not undo the other's update. The collision check concerns the main checkout, where carried paths live; a linked worktree is pulled from inside it, on its own machine.
- **`repos clone`** clones a registered repository that is absent on this machine, and does nothing else.
- **`files sync`** reconciles enrolled targets only and never changes git state. A target with an empty carry set starts no reconciler.
- **`files enroll`** discards any reconciler record of the target on both machines, inspects the carry set itself on both (existence and content hash, through the host seam), lists the paths that are equal, differing, and present on one machine only, then reconciles and writes the receipt on both. A path present on one machine only is copied to the other only with `--copy-missing`; without it the path is held. Enrolling again is how every blocked state that concerns receipts and records is cleared, and how a carry set the manifest has since extended is taken in.
- **A held path is released** by `files resolve` on it, by a later `files enroll --copy-missing`, or by a run that finds it present on both machines, where it then agrees or is skipped like any other.
- **`files resolve`** acts on one path that the last run skipped or the receipt holds, and refuses any other. It then runs the reconciler for the target so the outcome is recorded. `--keep <machine>` copies that machine's copy over the other's, by one reconciler run restricted to that path with the kept machine's root forced; `--delete` removes every copy. Before replacing or removing a copy it moves that copy to `~/.local/state/twin/replaced/<UTC time>/<target>/<path>` on the machine that held it, mode 600; nothing there is overwritten, and it stays until Qiushi removes it.
- **`dotfiles apply`** restows and renders. It loads the launchd agents of this machine's dotfiles package only with `--load-agents`; without it, such an agent that is not loaded is an attention item. A label Qiushi disabled with `launchctl disable` is informational and is never re-enabled. Agents owned by other repositories, the slack-digest pair among them, are not `twin`'s. `--replace-codex-config` discards local differences in the Codex config instead of stopping.
- **`twin tick`** on the laptop: `files sync --all`, `repos fetch --all`, record and publish the observation. On the mini: `repos fetch --all`, record the observation. It never pulls, installs or applies.
- **Exit status:** 0 when the command completed and there are no attention items; 1 when it completed and there are; 2 when it could not do what was asked (a bad manifest, a failed local git command, a peer that a state-changing command needed and could not reach). An unreachable peer during `twin status` is an attention item, exit 1.
- **The attention block** is the last thing printed. Per item it states the machine, the target, the condition, and the command or manual act that clears it. It lists unknown conditions as items. Informational lines appear before it and do not affect the exit status. When a status command names no target, a target with more than three items under one condition is one line that counts them and points at `twin status <target>`; the count on the first line and `--json` always carry every item.

Repository conditions. They are independent; a repository can have several at once.

| condition | scope | holds when | cleared by | attention |
| --- | --- | --- | --- | --- |
| absent | the repository on one machine | the manifest registers it and there is no checkout at its path | `repos clone` | yes |
| uncommitted | each worktree | modified, staged or untracked-unignored files | commit or discard | yes |
| unpublished | each branch with an upstream | the branch is ahead of its upstream | push | yes |
| local-only, in use | each branch with no upstream | it is checked out in a worktree | push, or remove the worktree | yes |
| local-only | each other branch with no upstream | always | nothing; informational | no |
| behind | each checked-out branch with an upstream | the upstream ref from the last successful fetch is ahead | `repos pull` | yes |
| fetch unknown | the repository | no fetch has succeeded, or the last one failed | a successful fetch | yes |
| unregistered | a git checkout under `~/dev` | the manifest does not register it | nothing; informational, shown by `repos status` with no target and kept out of the observation | no |

An observation carries two times per repository: when it was inspected, and when its last successful fetch finished. A peer's observation, as seen from this machine, is `live`, `recorded at <time>`, or missing; a missing one is an attention item.

Carry-set states, each the outcome of the last completed run for the target. They are recorded on the laptop and travel in its observation. A target with an empty carry set has no state and is not shown. A target has one state; where several rows apply, the first of blocked, failed, needs resolving, not enrolled wins, and skipped and held paths are still listed under it.

| state | entered when | left when | attention |
| --- | --- | --- | --- |
| not enrolled | the carry set is not empty and no receipt and no reconciler record exist | `files enroll` completes | yes |
| in step, as of the last run | a run completed with nothing skipped and nothing held | a later run finds otherwise | no |
| needs resolving | a run skipped a path (changed on both machines, or deleted on one), or the receipt holds a path | `files resolve` for each such path | yes |
| failed | the reconciler reported a transfer failure, or exited without completing | a run completes | yes |
| blocked | validation failed; the repository is absent on a machine; the two machines' declarations of the target differ; the manifest lists a carried path the receipt does not cover; or, of the two receipts and the two records, at least one exists and at least one is missing | the cause is fixed; the last two causes need `files enroll` | yes |

A run that cannot reach the peer changes no state: the last completed run's outcome stays, with its time, beside an attention item saying the peer was not reached.

A receipt also notes whether a reconciler run has left a record yet. A target whose every path is held has receipts and no record; that is enrolled, with its paths needing resolving, not blocked. The reconciler is never started with an empty path list, because it would then take the whole root.

A carried path edited after the last run is not a state `twin` observes; the next run reconciles it. A path the manifest no longer lists leaves the receipt at the next run and stays on both disks.

Walking the real inputs: `itell`'s `.env` files are equal on both machines, so enrollment records agreement and the set is in step. A carried file that differs between the machines at enrollment needs resolving. `greenflag`'s `.greenflag` is a directory: files added on either side merge, and one changed on both needs resolving. A repository freshly cloned on the mini has none of its carried files: enrollment holds them all unless `--copy-missing` is given.

Receipts, per method:

- **make-install:** the checkout's revision, read before the build, and whether the worktree had uncommitted changes. The tool is behind when the checkout's revision differs from the receipt's or the receipt is marked uncommitted.
- **pnpm-global:** the version `pnpm` reports as installed. Behind when it differs from the manifest's pin.
- **release-installer:** read from the installed app at each observation, not stored: its bundle version, and whether its signature is the notarized release. When both machines run a release and the versions differ, the older machine has an attention item cleared by `tools install` there. An app absent on a machine is an attention item there. A build from the working tree, or a peer with no observation, is informational.
- **dotfiles activation:** the dotfiles revision at the last successful `dotfiles apply`. Behind when the checkout has moved.

### Wiring

Dotfiles.

- Today: `mini-sync` rsyncs the laptop's tree, `.git` included, over the mini's with `--delete` (`scripts/.local/bin/mini-sync`, the `rsync -a --delete --copy-unsafe-links` line), then runs `make -s -C ~/dotfiles restow PACKAGES=…` there for a subset of packages.
- Today: the `Makefile`'s `PACKAGES` is every top-level directory minus a short deny list, so a new top-level directory is stowed on any machine that runs `make restow`.
- Today: skills owned by other projects are symlinks out of the tree; five are absolute paths under `/Users/qiushi` (`claude/.claude/skills/{read-email,write-email,slack,explain-diff,terminal-browser}`), which do not resolve under the mini's home `/Users/qiushiyan`. The mirror hides this by copying their targets as directories; in the mini's checkout they show as deletions of the tracked links. `skill-sync` raises on a broken link (`scripts/.local/bin/skill-sync`, "broken symlink").
- Today: `~/.gitconfig` on the mini is its own file; the `git` package is not stowed there. launchd agents live in the `scripts` package (`scripts/Library/LaunchAgents/`), which is why `scripts` is not stowed on the mini.
- After: both machines clone `https://github.com/qiushiyan/dotfiles.git`. `twin dotfiles apply` restows the manifest's packages for this machine through the `Makefile`, renders the Codex config, and re-sources the tmux config in a running server when `tmux.conf` changed since the last apply.
- After: launchd agents move into one package per machine, and the `Makefile`'s default package set includes this machine's package and never the other's, keyed on `~/.config/machine`; with no marker it includes neither. Sketch: `launchd-mac/`, `launchd-mini/`. The mini's gains the daily `com.qiushi.snapshot` agent and, at the cutover, both gain the `twin tick` agent.
- After: the out-of-tree skill links are relative, as `greenflag-concierge` already is. The targets that create them (`skills` in `~/dev/slackkit/Makefile` and `~/dev/mailkit/Makefile`) write relative links; the `explain-diff` link has no generating target and is rewritten in dotfiles. For `terminal-browser`, see Premises.
- After: the `git` package is stowed on both machines; `~/.gitconfig.personal` is a carried path of `home`.

Codex config.

- Before the cutover: on the laptop `~/.codex/config.toml` was a symlink to a tracked `config.toml` in the `codex` package, so Codex's runtime writes kept that file modified, and `skill-sync` wrote its generated block into the same file (`scripts/.local/share/dotfiles/skill-policy.yaml`, `codex_config`). On the mini the file was generated by `mini-codex-config.py`, since deleted, which drops the laptop-only tables and the top-level `notify`, forces `cli_auth_credentials_store = "file"`, keeps three runtime-owned tables from the mini's copy, and reverts every other local change.
- After: the tracked source is three files in the `twin` package, stowed beside the manifest and never linked into `~/.codex`: shared settings, and one fragment per machine holding the settings Qiushi wrote for that machine alone (the laptop's `shell_environment_policy.set`, the mini's `cli_auth_credentials_store`). What the ChatGPT desktop app writes on a machine that has it (`plugins`, `marketplaces`, `desktop`, its two MCP servers, `notify`) is runtime-owned like the trust tables: kept from the local file, never rendered from the source, so the app changing its own list is not drift. Sketch: `twin/.config/twin/codex/{shared,mac,mini}.toml`. `skill-sync`'s `codex_config` points at the shared file's path in the checkout.
- After: each machine's `~/.codex/config.toml` is a real file. `twin dotfiles apply` renders it from the shared file, this machine's fragment, and the runtime-owned tables kept from the local file. It keeps a copy of each render in its state directory. Before writing, it compares the local file with the last render, as parsed TOML and ignoring the runtime-owned tables: equal means nobody edited the local file, and the new render is written, whatever changed in the source. On a difference it stops and lists the differing keys. With no last render, the comparison is against what it is about to render. The change is then moved into the tracked source, or discarded with `--replace-codex-config`. Migration is therefore the first comparison. A `~/.codex/config.toml` that is still a symlink is read through and replaced by the rendered real file.
- Why both machines render: a tracked file that Codex modifies at every trust decision would keep the dotfiles target "uncommitted" on the laptop forever, and the attention block would never be empty. `claude/.claude/settings.json` is also written through its link, but only when Qiushi changes a setting; that item is a real one, to commit or discard.

Files.

- Today: `mini-sync` copies the paths in its `SECRETS` array to the mini with `rsync -aR` on every run, laptop to mini only.
- After: the laptop runs the reconciler, one run per target: roots are the target's directory on each machine (`$HOME` for `home`), restricted to the carry set, with deletion propagation off on both roots and no preferred side. The reconciler's record and `twin`'s receipts live in `~/.local/state/twin` on each machine, outside every carried path. The mini's `files` commands execute on the laptop through the host seam, and the laptop then reaches back to the mini.
- After: `twin` takes its own per-target lock for every run and passes the reconciler `-ignorelocks`. Only `twin` runs the reconciler on these roots, so a reconciler lock found while `twin` holds its own is left by a dead run.
- After: a held path is kept out of a run by leaving it off the path list, or, inside a carried directory, by an ignore rule for that one path. The receipt lists held paths, and that list is where their attention items come from.
- After, before every run, each carried path is validated on both machines. The target is blocked when a path:
  - is a file tracked in the main checkout's current `HEAD`, or is not ignored there. A carried directory may hold files git tracks beside its ignored ones: every run leaves those to git, through an ignore rule per tracked file on either machine, and the directory is refused only when it holds a file git neither tracks nor ignores;
  - resolves outside its root, or is protected;
  - is declared under `home` but lies inside a registered repository;
  - equals or lies inside another carried path;
  - is, or contains at any depth, a directory named as a build artifact: `node_modules`, `.next`, `.turbo`, `dist`, `build`, `target`, `.venv`, `__pycache__`.
- Carried paths belong to a repository's main checkout; linked worktrees are seeded by `gwt`, as now, and what another worktree's branch tracks does not matter.
- After, before every run, the laptop compares a digest of its declaration of the target with the mini's. On a difference the target is blocked and the item gives each machine's dotfiles revision; it names a machine as behind only when its revision is an ancestor of the other's.
- After, the paths a run skipped are read from the reconciler's batch output (`skipped: <path> (<reason>)`), which is where the "needs resolving" items come from.

Repositories.

- Today: `pp` (`zsh/.config/zsh/nav.zsh`) pulls the planlab checkout and its briefs clone on both machines through `_pull_both`, an ssh fan-out of its own; the briefs leg refuses any branch but `main`.
- After: `pp` is `twin repos pull planlab planlab-handoffs --both`, keeping its `--cd`. The briefs rule is the manifest's `branch = "main"`. `_pull_both` is deleted.
- After, in `repos pull`, between the fetch and the fast-forward: every path the incoming commits add is compared with the target's carry set. A carried path that equals such a path, lies inside one, or contains one, makes the pull refuse. Git treats an ignored file as expendable: a fast-forward that starts tracking it replaces its contents. A change to a file git already tracks inside a carried directory is not an addition and is git's own.
- After: `twin tick` fetches every registered repository on its machine, with the non-interactive settings of the host seam.
- After: unregistered checkouts are found by walking `~/dev` three levels deep for a `.git` directory, which skips linked worktrees, whose `.git` is a file.

Observations.

- After: each machine writes its own observation whenever `twin observe` runs. The laptop's tick copies its observation to the mini and runs `twin observe` there for the mini's; a live status command from either side reads the peer's and leaves its own there. Each machine therefore holds two files, its own and the last it received.

Session start.

- Today: `.claude/hooks/machine-context.sh` prints `.claude/machines/<name>.md`.
- After: the hook also prints `twin status dotfiles --recorded`, with a short time limit, and prints the machine text alone when `twin` is absent or slow.

Tools.

- Today: `mini-sync` copies the binaries in `BINS` from the laptop's `~/.local/bin`, copies `/Applications/TabType.app`, and matches the pnpm-global packages in `ENGINES` to the laptop's versions.
- After: `twin tools install` runs the manifest's method: `make install` in the checkout; `pnpm add -g` at the pinned version; or the checkout's own installer. TabType's `~/dev/tabtype/scripts/install-release.sh` verifies the release's signature first; it removes the installed app before copying the new one, and is changed in its own repository to stage and swap so a failed copy leaves the old app. The slack-digest agents on the mini stay slackkit's: a local target in `~/dev/slackkit/Makefile` installs and reloads them there, replacing its laptop-driven `install-mini`, and the cutover runs it once.

### Design it twice

- **Winner: resource modules behind a small command set, with the reconciler borrowed.** Constraint optimised: each kind of state has one owner whose failure modes it alone handles.
- **Rejected: three generic verbs (`status`, `sync`, `apply`) over a recipe manifest with a hand-written three-way file sync.** Optimised for few entry points. Lost because a target name meant a different thing to each verb, `sync` joined two jobs that fail differently, and a hand-written record of "last agreement" left enrollment, deletion and loss of the record undefined. The manifest carries no command lines for the same reason.
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
- in a carried directory, files added on each side are copied across, and a file changed on both is skipped as `skipped: d/same (contents changed on both sides)`;
- a second concurrent run fails on the lock, exit 3, and `-ignorelocks` runs past a lock file left behind; with one side's record deleted the run refuses, exit 3;
- a one-sided file left off the path list, or ignored by `-ignore 'Path d/only-a'` inside a carried directory, is not copied, and is copied by a later run without the rule;
- two copies made equal by hand after a conflict, and a path removed from both sides by hand after a skipped deletion, are each accepted by the next run, exit 0;
- a run killed during a 600 MB transfer left the destination at its old content, and the rerun converged;
- a no-op run over ssh took 0.56 s; the laptop's build is OCaml 5.4.1 and the mini's 5.5.0, and they interoperate.

Establishes: tenet 3's mechanism; the needs-resolving, failed and blocked states; path-exact skip reporting; the mechanisms of holding and of `files resolve`; that the record can live in a `twin`-owned directory on both machines. From the mini, `ssh mac` followed by `ssh qiushi-mini` from the laptop's session reached the mini, which is the path a `files` command from the mini takes.
Does not establish: any inspection that does not copy, which is why carry-set states are outcomes of the last run; the kill was timed by hand, once.

Decision: an ordinary sync never initialises a target; enrollment is its own command. Settled.
Basis: measured, same session: with both records deleted, Unison treats the next run as a first run and copied back a file that had been deleted on one machine. A receipt on both machines lets `twin` tell a lost record from a new target. When receipts and records are lost on both machines at once, the target is indistinguishable from a new one; the enrollment listing and `--copy-missing` are the remaining guard.

Decision: `UNISONLOCALHOSTNAME` is set to the machine name for both ends. Settled.
Basis: established from source and observed: the mini reports the DHCP name `Mac.lan` (`docs/zsh.md` § Machines), and Unison names its record after the host name.

Decision: `repos pull` checks the incoming tree against the carry set. Settled.
Basis: measured, 2026-10-05, in scratch repositories: a clean checkout holding an ignored file was fast-forwarded to a commit that tracks the same path, and the file's contents were replaced without a refusal.

Decision: personal CLIs are built on each machine. Settled.
Basis: measured, 2026-10-05, on the mini: `go build ./...` succeeded in the clones of `headroom`, `envoy`, `brief`, `gwt`, `gopen`, `cout`, `slackkit` (two binaries), `claude-steps` and `degit`; each has a `make install` target except `degit`, which is not a tool here.
Does not establish: that each `make install` runs clean on the mini.
Fallback: a tool whose install fails there keeps the binary `mini-sync` last copied, and stays an attention item until its repository is fixed; the design does not change.

Decision: git runs over HTTPS on both machines, including when driven over ssh. Settled.
Basis: measured, 2026-10-05: with the laptop's `gh` token in its keyring, `git` on the laptop failed from an ssh session (`could not read Username for 'https://github.com'`); with the token in `~/.config/gh/hosts.yml`, as on the mini, `pp` run on the mini completed on both machines (`docs/qiushi-mini.md` § Reaching the laptop). Every clone on both machines had an HTTPS origin after a scan the same day, and the stowed `git/.gitconfig` rewrites SSH GitHub URLs.
Does not establish: the same under launchd; obligation 18 observes it.

Decision: terminal-browser's skill link is untracked and gitignored; each machine's own installer writes it. Settled.
Basis: established from source, 2026-10-05, terminal-browser v0.11.1 (`linkSkills` in its CLI bundle): `setup`, which `upgrade` runs, removes any existing symlink at `~/.claude/skills/terminal-browser` and writes a new one whose target is the absolute path of that machine's install. A tracked relative link would be rewritten at every upgrade, and the rewritten one resolves under one home only.
Establishes: no machine holds a broken link, and the tracked tree never changes under an upgrade. The other four links that leave the tree are relative and resolve under either home.
Does not establish: that terminal-browser installs on the mini; it is not installed there, and nothing here needs it.

Decision: a carried directory may contain tracked files. Settled.
Basis: observed, 2026-10-05: `~/dev/greenflag/.greenflag` holds its ignored working documents beside a tracked `.gitignore` and template. Held by a test in `~/dev/twin` (`TestCarriedDirectoryWithTrackedFiles`): the reconciler copies the ignored file, leaves the tracked one for git, and a pull that changes the tracked one is not refused while one that adds a file there is.

## Verification

The build reports each obligation below by number: pinned, a test that goes red when the behaviour is removed; nominal, a test that exists but would stay green; or skipped, with the reason.

Unless stated otherwise: observed through `twin`'s commands, in Go tests in `~/dev/twin`, with two temporary homes behind the local host adapter, real `git`, and the real Unison binary run against two local roots. Unison then keeps one record file per root in one directory; removing one of them is "the record missing on one machine". Both programs are installed on both machines. The ssh adapter is exercised only in obligations 17 to 19.

1. A carried path changed in one home is equal in both after `files sync`, with its mode kept.
2. A carried path changed in both homes is unchanged in both after `files sync`; the attention block names the path; exit status is 1; a second run names it again.
3. A carried path deleted in one home is still present in the other after `files sync` and is listed; `files resolve --delete` removes both; `--keep` naming the machine that has it restores it; `--keep` naming the other is refused. Every copy `files resolve` replaced or removed is found under `replaced/` with mode 600, two resolutions of one path leaving two copies, and the target is in step afterwards. `files resolve` on a path that is neither skipped nor held is refused.
4. `files sync` on a target with no receipt and no record changes no file and reports it not enrolled. With a receipt present and one root's record removed, or with a carried path added to the manifest after enrollment, it changes no file and reports the target blocked; so it does with records present and both receipts removed. `files enroll` without `--copy-missing` leaves a one-sided path on one side only, in a carried directory too, and later `files sync` runs keep it there; with the flag it copies it.
5. A carry set is refused before the reconciler starts when a path: is tracked in the main checkout's `HEAD`; is untracked but not ignored; escapes its root through a symlink; is protected; lies inside another carried path; is declared under `home` but lies inside a registered repository; or contains `node_modules`. A path ignored on the main checkout's branch and tracked only on a linked worktree's branch is accepted.
6. With the two homes holding different declarations of one target, `files sync` changes no file and gives both dotfiles revisions.
7. A target with an empty carry set starts no reconciler process.
8. `repos status` reports each condition in § Design — API for the main checkout and for a linked worktree; a repository that has never fetched, or whose remote is unreachable, has "fetch unknown"; a branch with no upstream that is not checked out is informational and does not change the exit status.
9. With the peer adapter failing, `twin status` shows the peer's recorded observation with its time and exits 1, or lists the missing observation as an item; `--recorded` makes no call through the peer adapter.
10. A command made to fail after its first target still prints the attention block, and the same items under `--json`.
11. `repos pull` fast-forwards a clean worktree; refuses a dirty one, a diverged one, one on the wrong `branch`, and one where the incoming tree starts tracking a carried path, leaving that path's contents intact; with `--both` and one side refusing, the other side's result is reported as completed. No `twin` command creates a commit or a push: asserted over the fixture remotes across the suite.
12. A failing install leaves the tool behind; a succeeding one writes its receipt; an install from a checkout with uncommitted changes is reported as such, not as current.
13. In `~/dev/twin` (`TestDotfilesApply`), with the launchd selection also held against the real `Makefile` by a case in `zsh/.config/zsh/tests/stow-reach.test.zsh`: `dotfiles apply` on a fixture tree shaped like the one after the cutover commit, in a temporary home that starts from today's layout, with `~/.codex/config.toml` a symlink to the file that used to be tracked, leaves `~/.claude` and `~/.codex` real directories, stows this machine's launchd package only, and replaces the symlink with a real file. The Codex source is a fixture in the test. The rendered Codex config keeps the runtime-owned tables read through the old link, includes this machine's fragment and not the other's; a local edit outside the runtime-owned tables stops the render and is listed, while a change in the source with no local edit renders without a flag. `zsh/.config/zsh/tests/stow-reach.test.zsh` stays green.
14. In dotfiles: the session-start hook prints the machine text and the dotfiles items with the network unavailable, and the machine text alone with no `twin` on `PATH`. Extends `.claude/hooks/test-machine-context.sh`.
15. `repos clone` creates an absent registered checkout from the manifest's URL and refuses a path that already exists.
16. In `~/dev/tabtype`: the installer, made to fail at the copy, leaves the previously installed app in place.
17. Live, after the cutover: a commit made in the mini's `~/dotfiles` is still at its `HEAD` after the laptop's next `twin tick`, and `launchctl print` shows no `com.qiushi.mini-sync` on the laptop after a logout and login. Manual, once.
18. Live, after the cutover: the `twin tick` run by launchd on each machine records a fetch time newer than the previous one. Manual, once per machine; it shows the credential is readable in that context.
19. Live, after the cutover: `twin files sync home` from the mini with the laptop awake, then asleep. Manual; the second run must exit 2 and name the laptop.

Limit: the fixtures cannot show the reconciler's behaviour between two OCaml builds or over a dropped tailnet link; the first was measured once (§ Design — Premises).

## Delivery

Boundary: two repositories carry the design. `twin` is new, in `~/dev/twin` (`github.com/qiushiyan/twin`, private), because it is a tool with its own tests, like `headroom` and `gwt`. The dotfiles changes land on `main` in the phases below, because phase 3 is an operational step on two live machines and the old writer must be gone before it. Three other repositories take small changes before phase 3: `~/dev/slackkit` (relative skill links; a local agent-install target), `~/dev/mailkit` (relative skill links), `~/dev/tabtype` (the installer stages and swaps). `~/dev/tabtype/docs/releasing.md` changes in phase 4.

1. **Build `twin`** against fixtures: obligations 1 to 12 and 15.
2. **Prepare**, with `mini-sync` still running and the mini's behaviour unchanged:
   - in dotfiles: the `twin` package with the manifest; relative skill links; the per-machine launchd packages and the `Makefile` rule that selects one; the hook change. Obligations 13 and 14. Each change is correct under the mirror, since the mirror copies it.
   - the three owning-repository changes above; obligation 16.
   - terminal-browser's link leaves the tracked tree (§ Design — Premises).
3. **Cut over**, with both machines awake, in one sitting with phase 4:
   1. On the laptop: `launchctl bootout` and `launchctl disable` the `com.qiushi.mini-sync` label, and confirm no `mini-sync` process is running. Nothing else proceeds until this holds. From here until phase 4 deletes it, `mini-sync` is not run by hand.
   2. Take an APFS snapshot on both machines (`snapshot`).
   3. On the laptop: replace the `~/.codex/config.toml` symlink with a copy of what it points at, so the live file is detached before its source shrinks.
   4. On the laptop, one commit, pushed:
      - remove the `mini-sync` plist from the laptop's launchd package;
      - reduce the Codex source to the three files in the `twin` package, and point `skill-sync`'s `codex_config` at the shared one;
      - reword `.claude/machines/mac.md`, `.claude/machines/mini.md`, the "Know which machine this is" bullet in `CLAUDE.md`, and the unidentified-machine message in `.claude/hooks/machine-context.sh`. None may still describe a mirror. Each machine text states which machine this is, that the checkout is a clone, and that a commit reaches the other machine only once pushed;
      - make `zsh/.zshrc` source `~/.secrets.shared` and then `~/.secrets`, and on the laptop move the shared keys (§ Design — Manifest) from `~/.secrets` into a new `~/.secrets.shared`, mode 600.
   5. On the mini: fetch; list the differences between the working tree and its `HEAD`. The copied skill directories are replaced with the tracked links; the copy of terminal-browser's, now ignored and with no app behind it there, is removed. Any other modified tracked file is the laptop's uncommitted edit, mirrored: it is discarded on the mini once the same path is seen modified or committed on the laptop. An untracked, unignored file the laptop does not have stops the cutover for Qiushi to look at. Then `git pull --ff-only`, and `skill-sync --check`. Ignored files, the tmux plugin clones and `claude/.claude/skills/synced/` among them, are left alone: no `git clean -x`.
   6. On the mini: clone `~/dev/twin`, `make install`, and stow the `twin` package once by hand so the manifest is readable. The hand-written `~/.gitconfig`, which holds the mini's credential helper, is still in place for the clone.
   7. On the mini: run the restow in simulation (`stow -n`) for its package list. Each conflict is a file or link made by hand or by `mini-sync`, `~/.gitconfig` and the `~/.codex` links among them; move each aside. On both: `twin dotfiles apply`, without `--load-agents`. The first Codex render stops on any difference; each is adopted into the tracked source or discarded.
   8. On both: `twin tools install --all`. On the mini: slackkit's local agent-install target.
   9. On the laptop: `twin files enroll` for each target with a carry set, reading each listing before adding `--copy-missing`; `home` needs it for `~/.secrets.shared` and `~/.gitconfig.personal`, which exist on the laptop only. Resolve what each lists. Then remove the `CONTEXT7_API_KEY` line from the mini's `~/.secrets`, now that the shared file supplies it.
   10. On the laptop, one commit, pushed, then pulled on the mini: add the `twin tick` agent to both launchd packages. On both: `twin dotfiles apply --load-agents`. Obligations 17 to 19.
4. **Clean up the old sync family in dotfiles**: delete `mini-sync`, `mini-codex-config.py` and `_pull_both`; rewrite `pp`; correct the obelisk skill's upgrade note; change step 8 of `~/dev/tabtype/docs/releasing.md` to the tools command; delete this spec. The live docs that describe the mirror are brought in line by Qiushi's `/update-docs` pass, which the repository's convention leaves to him to start (`docs/doc-loop.md`). `claude-tomini`, `tomini`, `frommini`, `theme-set`, `skill-sync`, `secrets-manifest.txt` and `scripts/list-secrets.sh` stay (§ Intent, non-goals).

Phases 1 and 2 fit one session; 3 and 4 a second, with a handoff between.

### Open

No product decision is open, and no premise is still proposed.

## As built

What the build changed, beyond the edits made in place above:

- **dotfiles was not pushed during the cutover.** The repository's rule leaves pushes to Qiushi, so the mini took the cutover commits from the laptop over ssh (`git pull --ff-only mac:dotfiles main`). Both checkouts are at the same commit and both report it unpublished until `git push`. `twin`, `slackkit`, `mailkit` and `tabtype` were pushed.
- **The wiki is on the mini, with its gitignored originals.** Qiushi's decision after the cutover: the mini holds a clone, and the wiki's carry set is `sources`, whose ignored subfolders travel while the extracts git tracks stay git's, and `.consult`. This reverses the non-goal in § Intent. The mini's copy is a replica, not a backup. Finder's `.DS_Store` is never carried, in any target.
- **claude-steps is built on both machines from one pushed branch.** The laptop's checkout was on a branch with no upstream, which the mini could not fetch; the branch was pushed, the mini switched to it, and both built it.
- **Enrollment met copies equal in content and different in mode** (644 on the laptop, 600 on the mini, eight paths). With no record the reconciler cannot pick a side for a permission difference; the laptop's were tightened by hand to match, and `files enroll` now lists such paths as "same content, modes differ".
- **The reconciler's state directory must exist on the machine it reaches.** Unison creates the directory but not its parents; the peer's inspection now creates it. Found at the first real enrollment, where the local adapter could not show it.
- **`git-delta` was installed on the mini**, which the stowed `git/.gitconfig` names as its pager.
- **Left in place as backups**, for Qiushi to remove: `~/.codex/config.toml.pre-twin` on both machines, `~/.gitconfig.pre-twin` and `~/.local/state/mini-sync` on the mini.

Obligations:

1. Pinned: `TestOneSidedChangePropagates`.
2. Pinned: `TestTwoSidedChangeWaits`.
3. Pinned: `TestDeletionAndResolve`.
4. Pinned: `TestEnrollment`, `TestEverythingHeld`.
5. Pinned: `TestValidation`, `TestCarriedDirectoryWithTrackedFiles`.
6. Pinned: `TestDeclarationSkew`.
7. Pinned: `TestEmptyCarrySetStartsNothing`.
8. Pinned: `TestRepoConditions`.
9. Pinned: `TestPeerUnreachable`.
10. Pinned: `TestBlockSurvivesFailure`.
11. Pinned: `TestPull`; the no-commit, no-push assertion wraps every `twin` run in the suite.
12. Pinned: `TestToolReceipts`.
13. Pinned: `TestDotfilesApply`, and `stow-reach.test.zsh`'s launchd case against the real `Makefile`. The tmux re-read is not under test: nothing in the suite may reach a tmux server.
14. Pinned: `.claude/hooks/test-machine-context.sh`, with a stub `twin`; that `--recorded` makes no call to the other machine is obligation 9.
15. Pinned: `TestClone`.
16. Pinned: `~/dev/tabtype/scripts/test-install-release.sh`, red against the old script.
17. Observed for the commit: one made in the mini's `~/dotfiles` was at its `HEAD` after the laptop's launchd tick. Not observed after a logout: the `com.qiushi.mini-sync` label is booted out and disabled and its plist is deleted, and nobody has logged out since.
18. Observed on both machines: the launchd-run tick recorded a successful fetch.
19. Observed with the laptop awake: `twin files sync home` from the mini, exit 0. Not run with the laptop asleep; the unreachable path is held in the suite by the local adapter only.

Each pinned test went red under a mutation that removed its behaviour, and green again restored.
