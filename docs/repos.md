# Repositories — what each one is and what here depends on it

Before a session here changes another repository, or sends a change to
one, this doc says which repository owns the change and what here depends
on it. It covers the repositories `twin` keeps on every machine, then
iTELL's, which live on the laptop only. Each lives at `~/dev/<name>` unless
its entry gives another path. Paths and remotes are in
`twin/.config/twin/twin.toml`, and `twin repos clone <name>` brings in a
missing one.

## Changing another repository from here

A change that crosses repositories is done when both halves are committed.
When a tool changes, the skill or doc here that describes it changes too,
and each half is committed in its own repository under that repository's
rules.

## Session tooling

The Go CLIs and skills that agent sessions run on. Most are linked or
installed into this repository's packages, so a change to one often brings
along a skill or doc here.

- **brief:** carries work between sessions; it indexes the briefs under
  `~/dev/.handoffs/<project>/`. The handoff, consult, review and archify
  skills here call it, and `zsh/` completes its arguments.
- **drive:** the commands a driver (a chat bot or a Claude Code session)
  uses to run Claude Code sessions in Rex. The `drive-session` skill here
  relies on drive's messages (`CLAUDE.md` § Cross-package features).
- **envoy:** runs headless `claude` and `codex` turns as named jobs. The
  consult, review and improve-tool skills here dispatch through it.
- **headroom:** picks the account with quota left and launches the vendor
  on it. The `x*` launchers in `zsh/.config/zsh/claude.zsh` and the quota
  mod depend on it (`docs/claude-accounts.md`).
- **claude-steps:** shows what ran in each Claude Code session. The
  `prefix S` popup and its label config are here
  (`tmux/.config/tmux/scripts/steps.md`).
- **ccclean:** keeps the Claude session store's retention and its mirror
  (`docs/claude-sessions-store.md`). `twin tools install ccclean` builds it
  on each machine, and the `com.qiushi.ccclean-mirror` agents run it.
- **gwt:** places worktrees and decides when one may be removed. The
  `prefix W` popup, the zsh `gwt` function, the worktree mod and the
  clean-worktrees skill call it (`tmux/.config/tmux/scripts/worktree.md`).
- **twin:** keeps the machines in step. Its manifest and runbook are here
  (`docs/twin.md`).
- **cout:** records the commands run in panes and copies one together with
  its output. tmux `prefix o` and the zsh hooks are here.
- **gopen:** opens the current checkout on GitHub. tmux, zsh and git
  bindings here call it.
- **clikit:** the invocation and help contract every Go CLI under `~/dev`
  builds on, so a change to it reaches each CLI that upgrades. The `go-cli`
  skill here owns how those CLIs are maintained.
- **mailkit:** lets agents read mail and send it only after the person has
  seen it. The `read-email` skill is linked from it.
- **slackkit:** the Slack engine and the apps built on it. The `slack` skill
  is linked from it.
- **skill-evals:** runs a skill's test cases headless against chosen
  revisions (`docs/agent-skills.md` § Testing a skill by running it).
- **tabtype:** the macOS app behind `;;` snippet completion. The snippet text
  is in this repository's `tabtype/` package and the app is in that repo. A
  release reaches every user of the app (`docs/session-pipeline.md`).

## Work

- **planlab** (`~/dev/planlab/main`): the team's repository, worked on in
  worktrees. This repository's layer over it is `docs/planlab.md`.
- **aws-login:** signs the AWS CLI in to planlab's Identity Center
  session; the laptop's Codex automation that keeps planlab-prod signed
  in runs it.
- **planlab-handoffs** (`~/dev/.handoffs/planlab-main`): the team's handoff
  briefs, which `brief` indexes.

## Personal

- **wiki** (`~/wiki`): the personal wiki behind the `wiki` skill.

## On the laptop only

iTELL work belongs to the laptop, so `twin` registers neither of its
repositories: `itell`, learlab's iTELL platform, where sessions start in
`apps/platform` and work goes through branches and PRs, and `itell-cms`, its
content management system. The `drive-session` skill's `ITELL.md` drives
sessions there. The laptop has no backup (`docs/recovery.md`), so mini2
keeps a copy of their gitignored env files in `~/archive/itell-carried`.
