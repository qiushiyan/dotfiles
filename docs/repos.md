# Repositories — what each one is and what here depends on it

These are the repositories `twin` keeps on every machine. Its manifest,
`twin/.config/twin/twin.toml`, holds each one's path and remote, and
`twin repos clone <name>` brings a missing one in. This doc covers what the
manifest cannot: what each repository is for and which parts of this one
depend on it. A session here can use it to tell which repository owns a
change before editing anything. Each repository lives at `~/dev/<name>`
unless its entry gives another path.

## Changing another repository from here

- **Read its own instructions before the first edit there:** its
  `CLAUDE.md`, else `AGENTS.md`, else `README.md`. They set its commit
  policy, its tests and how it installs, and those differ between
  repositories: drive commits on `main`, while headroom gives each piece of
  work its own branch. Claude Code loads another repository's `CLAUDE.md`
  only when the session moves there with `/cd`, or when that directory was
  added with `--add-dir` while `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD`
  is set. Reading or editing a file there from a session started here, or
  running `cd` in the shell, loads nothing.
- **Commit each file in the repository that owns it.** A tool and the skill
  or doc here that describes it change together but are committed in their
  own repositories.

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
  mod depend on it, and engine fixes belong there
  (`docs/claude-accounts.md`).
- **claude-steps:** shows what ran in each Claude Code session. The
  `prefix S` popup and its label config are here
  (`tmux/.config/tmux/scripts/steps.md`).
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
- **ccclean:** keeps `~/.claude` from growing without bound. The launchd
  packages here schedule it.
- **mailkit:** lets agents read mail and send it only after the person has
  seen it. The `read-email` skill is linked from it.
- **slackkit:** the Slack engine and the apps built on it. The `slack` skill
  is linked from it.
- **skill-evals:** runs a skill's test cases headless against chosen
  revisions (`docs/agent-skills.md` § Testing a skill by running it).
- **explain-diff:** turns a branch's changes into a served, interactive
  walkthrough. Its skill is linked from it.
- **tabtype:** the macOS app behind `;;` snippet completion. The snippet text
  is in this repository's `tabtype/` package and the app is in that repo. A
  release reaches every user of the app (`docs/session-pipeline.md`).

## Work

- **planlab** (`~/dev/planlab/main`): the team's repository, worked on in
  worktrees. This repository's layer over it is `docs/planlab.md`.
- **planlab-handoffs** (`~/dev/.handoffs/planlab-main`): the team's handoff
  briefs, which `brief` indexes.
- **itell:** the iTELL learning platform. Sessions start in
  `apps/platform`, and work goes through branches and PRs.
- **itell-cms:** iTELL's content management system.

## Personal and dormant

- **wiki** (`~/wiki`): the personal wiki behind the `wiki` skill.
- **degit:** a Go port of degit, installed through the Brewfile.
- **jev-openrouter-gallery:** runnable OpenRouter demos. Nothing here
  depends on it.
- **raycast-tab-utils:** a Raycast extension for the current browser tab.
  Nothing here depends on it.
- **greenflag:** a semi-AFK orchestrator for a two-worker workflow. It is no
  longer maintained.
