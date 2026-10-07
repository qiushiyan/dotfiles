# Dotfiles

This is the user's dotfiles collection managed with GNU Stow. Package trees mirror `$HOME`: `zsh/.zshrc` maps to `~/.zshrc`,
`nvim/.config/nvim/` to `~/.config/nvim/`. **Files are symlinked, so edits
here affect the live system immediately.** `docs/` is excluded from Stow;
`make list` and the tree show the packages.

Keep configuration reproducible without bringing private state into Git.
Secrets belong in untracked `~/.secrets.shared` (keys both machines use) or
`~/.secrets` (this machine's own), sourced by `.zshrc`; tracked config reads
them from the environment.

## Red lines

1. **`~/.claude`, `~/.codex`, `~/.agents`, and `~/.config/lazygit` stay real
   directories, never folded symlinks.** Link tracked config per item so
   runtime state such as credentials and sessions stays outside this public
   repo. Read `docs/stow-layout.md` before changing installation or the
   `.gitignore` allow-lists that protect this boundary.
2. **`claude/.claude/CLAUDE.md` stays empty.** It reaches every project as
   `~/.claude/CLAUDE.md`. A `<pkg>/CLAUDE.md` also reaches every project as
   `~/CLAUDE.md` unless the package's `.stow-local-ignore` excludes it, as
   `tabtype/` does. Put Claude configuration guidance in `docs/`. The guard
   is `zsh/.config/zsh/tests/stow-reach.test.zsh`.
3. **Tests must isolate live state and exercise the intended behavior.**
   An escaped sandbox can corrupt the machine; a test that exercised nothing
   can still pass. Run suites and experiments from a scratch directory, never
   from this checkout: an empty path read from test state resolves to `.`,
   and one such delete emptied the repository, `.git` included. Read
   `docs/testing.md` before adding a case.

## Working here

- **Know which machine this is: both hold a clone of this repository, and a
  commit reaches the other only once it is pushed and pulled.**
  `~/.config/machine` holds `mac` or `mini`, and `.claude/machines/<name>.md`
  says what differs there. Claude Code gets that file at session start, with
  `twin`'s state of this checkout (`.claude/hooks/machine-context.sh`); any
  other agent reads it first.
- Edits are live; no build. Use `make restow` after file additions or removals
  that require new links. `dotadd <path>` brings an unmanaged file under Stow.
- Commit directly on the current branch without asking; push after milestone implementation has finished.
- For shortcut or usage questions, read the tool's config and
  `tmux/.config/tmux/workflow.md`; treat the request as read-only.
- For theme additions or ports, follow `.claude/skills/add-theme/SKILL.md`
  (`/add-theme`, or `$add-theme` in Codex). `docs/theming.md` owns the system
  model across tools.
- For shell startup, the modules under `zsh/.config/zsh/`, or shell slowness,
  read `docs/zsh.md` first.

For implementation requests, finish the authorized work and report the outcome
and verification, including anything unverified. For design discussions, deliver
an assessment. Ask for input when scope, destructive actions, or missing facts
require the user's judgment; routine implementation choices are yours.

## Skill maintenance

For skill, lesson, or agent-doc work, read `docs/agent-skills.md` (ownership,
installation caveats, synchronization) and `docs/doc-loop.md` (session
conventions). Ownership decides whether a skill's body may be edited and where
lessons belong; lessons under `lessons/.config/lessons/` are reference
material, not invokable skills.

Edit personal skills in `claude/.claude/skills/` (`~/.agents/skills` is its
alias, shared with Codex) and repo-local skills in `.claude/skills/`; edit
externally linked skills in their owning projects. Keep custom skills and
forks out of `claude/.agents/.skill-lock.json`, because updates replace managed
files; `docs/skill-customizations.md` says what an upgrade of an adapted skill
must preserve.

After any skill edit, install, update, or removal, and after editing
`docs/documentation-standards.md`, run `skill-sync`, then `skill-sync --check`,
and commit skills, generated metadata/config, policy, and lockfile together.

## Cross-package features

Read the owning docs before changing a feature that spans packages:

- **Claude context chip** (`claude/`, `tmux/`, `zsh/`):
  `tmux/.config/tmux/scripts/context-chip.md`. `tmux-agent-status.sh` alone
  turns pane borders off.
- **Worktrees** (`tmux/`, `~/dev/gwt`, the clean-worktrees skill):
  `tmux/.config/tmux/scripts/worktree.md`. gwt owns placement, listing,
  every merged verdict and removal; the `prefix W` popup owns windows and
  prompts.
- **Session board** (`tmux/`, `claude-steps/`, `~/dev/claude-steps`):
  `tmux/.config/tmux/scripts/steps.md`. Neither the `claude-steps` binary nor
  the `prefix S` popup sends anything to a session.
- **Claude accounts:** `docs/claude-accounts.md`. The `x*` launchers in
  `zsh/.config/zsh/claude.zsh` delegate routing and validation to headroom
  (`~/dev/headroom`); engine fixes belong in that project.

## Documentation

Keep one file per topic under `docs/`; inspect that directory before calling
something undocumented. Live docs describe current design and runbooks;
Git holds shipped proposals. `docs/documentation-standards.md` is the shared
standard, maintained here and copied into other projects by `skill-sync`; this
repository's bindings and protected set are in `docs/doc-loop.md` § The doc
shape that keeps onboarding cheap.

Additional routes beyond the feature docs above:

- Auto-compaction settings: `docs/claude-autocompact.md`.
- Claude Code mods, in-session hooks with UI such as the quota toasts, and how
  one settings line loads them on every account: `docs/claude-mods.md`.
- AWS SSO sessions and the `aws-login` wrapper: `docs/aws-sso.md`.
- What protects uncommitted and gitignored state, local snapshots, recovery
  after a loss, bringing back a dead tmux server and its Claude sessions, and
  reading or editing the VPN credentials in 1Password: `docs/recovery.md`.
- Working across the laptop and the office mini: what moves by git, what
  `twin` carries, what each machine builds for itself, and what to run when a
  change made on one is needed on the other: `docs/twin.md`. Read it before
  adding a repository, a carried file, a tool or a launchd agent, and when
  `twin status` shows something to clear.
- The office Mac mini as a machine (`ssh qiushi-mini`), "the mini" everywhere
  in this repository: reaching it over the company tailnet, its desk, its
  toolchain and the jobs it hosts: `docs/qiushi-mini.md`.
- Unbuilt tmux features: `tmux/.config/tmux/roadmap.md`.
- The personal Slack toolkit: the `slack` skill is `~/dev/slackkit`'s,
  linked here; its design is that repo's `docs/`.

