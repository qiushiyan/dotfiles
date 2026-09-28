# Dotfiles

This is the user's dotfiles collection managed with GNU Stow. Package trees mirror `$HOME`: `zsh/.zshrc` maps to `~/.zshrc`,
`nvim/.config/nvim/` to `~/.config/nvim/`. **Files are symlinked, so edits
here affect the live system immediately.** `docs/` and `vpn-private/` are
excluded from Stow; `make list` and the tree show the packages.

Keep configuration reproducible without bringing private state into Git.
Secrets belong in untracked `~/.secrets`, sourced by `.zshrc`; tracked config
reads them from the environment.

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

- **On the office mini (`$USER` is `qiushiyan`), this checkout is a
  read-only mirror.** The laptop's `mini-sync` overwrites it every
  hour, so an edit here is lost. Make the change on the laptop, or report
  it for the user to make. `docs/qiushi-mini.md` § Sync.
- Edits are live; no build. Use `make restow` after file additions or removals
  that require new links. `dotadd <path>` brings an unmanaged file under Stow.
- Commit directly on the current branch without asking; leave pushes to the user.
- For shortcut or usage questions, read the tool's config and
  `tmux/.config/tmux/workflow.md`; treat the request as read-only.
- For theme additions or ports, follow `.claude/skills/add-theme/SKILL.md`
  (`/add-theme`, or `$add-theme` in Codex). `docs/theming.md` owns the system
  model across tools.
- For shell startup, files sourced by `.zshrc`, or shell slowness, read
  `docs/zsh.md` first. Keep `zsh/.config/zsh/git.zsh` usable without zle or
  rc dependencies: `.zshenv` sources it in every zsh, non-interactive ones
  included.

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
must preserve. Install or update upstream skills globally, both agents
selected, after checking for uncommitted skill edits:

```bash
npx skills@latest add <owner/repo> --skill <skill-name> -g -a claude-code codex -y
npx skills@latest update -g -y
```

After any skill edit, install, update, or removal, and after editing
`docs/documentation-standards.md`, run `skill-sync`, then `skill-sync --check`,
and commit skills, generated metadata/config, policy, and lockfile together.

## Cross-package features

Read the owning docs before changing a feature that spans packages:

- **Claude context chip** (`claude/`, `tmux/`, `zsh/`):
  `tmux/.config/tmux/scripts/context-chip.md`. `tmux-agent-status.sh` alone
  turns pane borders off; weekly quota comes from headroom.
- **tmux pane control:** floating and relocation use
  `tmux/.config/tmux/scripts/float-pane.md`; pane-mode bindings and undo use
  `tmux/.config/tmux/scripts/pane-mode.md`.
- **Worktrees** (`tmux/`, `~/dev/gwt`, the clean-worktrees skill):
  `tmux/.config/tmux/scripts/worktree.md`. gwt owns placement, listing and
  every merged verdict; the `prefix W` popup owns windows and removal.
- **Claude accounts:** `docs/claude-accounts.md`. The `x*` launchers in
  `zsh/.config/zsh/claude.zsh` delegate routing and validation to headroom
  (`~/dev/headroom`); engine fixes belong in that project.
- **Neovim-aware path copy** (`nvim/`, `tmux/`):
  `tmux/.config/tmux/workflow.md`. Neovim publishes the pane options;
  tmux reads them for `prefix y`/`Y`.

## Documentation

Keep one file per topic under `docs/`; inspect that directory before calling
something undocumented. Live docs describe current design and runbooks;
Git holds shipped proposals. `docs/documentation-standards.md` is the shared
standard, maintained here and copied into other projects by `skill-sync`; this
repository's bindings and protected set are in `docs/doc-loop.md` § The doc
shape that keeps onboarding cheap.

Additional routes beyond the feature docs above:

- Auto-compaction settings: `docs/claude-autocompact.md`.
- AWS SSO sessions and the `aws-login` wrapper: `docs/aws-sso.md`.
- Dormant Claude `cd` read guard: `docs/bypass-cd-read-guard.md`.
- The colleague's Mac mini (`ssh macmini-shared`), including access etiquette:
  `docs/macmini.md`.
- My own office Mac mini (`ssh qiushi-mini`), reached over the company
  tailnet and kept in sync by `mini-sync`: `docs/qiushi-mini.md`.
- Unbuilt tmux features: `tmux/.config/tmux/roadmap.md`.
- TabType prompt snippets: `tabtype/CLAUDE.md`.

