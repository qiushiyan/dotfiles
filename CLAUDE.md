# Dotfiles

This public repository manages the user's live machine configuration with
GNU Stow. Package trees mirror `$HOME`: `zsh/.zshrc` maps to `~/.zshrc`,
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
   can still pass. Read `docs/testing.md` before adding a case.

## Working here

- Edits are live; no build. Use `make restow` after file additions or removals
  that require new links. `dotadd <path>` brings an unmanaged file under Stow.
- Commit directly on `main`; leave pushes to the user.
- For shortcut or usage questions, read the tool's config and
  `tmux/.config/tmux/workflow.md`; treat the request as read-only.
- For theme additions or ports, follow `.claude/skills/add-theme/SKILL.md`
  (`/add-theme`, or `$add-theme` in Codex). `docs/theming.md` owns the system
  model across tools.
- For shell startup, files sourced by `.zshrc`, or shell slowness, read
  `docs/zsh.md` first. Keep `zsh/.config/zsh/git.zsh` usable without zle or
  rc dependencies: tmux's `scripts/tmux-gopen.sh` sources it non-interactively
  for `prefix g`.

For implementation requests, finish the authorized work and report the outcome
and verification, including anything unverified. For design discussions, deliver
an assessment. Ask for input when scope, destructive actions, or missing facts
require the user's judgment; routine implementation choices are yours.

## Skill maintenance

For skill, lesson, or agent-doc work, read `docs/agent-skills.md` for ownership
and `docs/doc-loop.md` for the session conventions. Ownership determines whether
a skill's body may be edited and where lessons belong. Lessons under
`lessons/.config/lessons/` are reference material, not invokable skills.

Edit personal skills in `claude/.claude/skills/`; `~/.agents/skills` is a
symlink alias shared with Codex. Repo-local skills live in `.claude/skills/`.
Edit externally linked skills in their owning projects. Codex's bundled
`~/.codex/skills/.system/` has a separate lifecycle.

Before an upstream update, check for uncommitted skill edits. Keep custom
skills and forks outside `claude/.agents/.skill-lock.json`, because updates
replace managed files. For adapted skills, read `docs/skill-customizations.md`
for what an upgrade must preserve.

Install upstream skills globally with both agents selected:

```bash
npx skills@latest add <owner/repo> --skill <skill-name> -g -a claude-code codex -y
```

Update managed skills with global scope:

```bash
npx skills@latest update -g -y
```

The existing folder links handle these installs; no `--copy`, per-skill
symlinks, or restow is needed.

After any skill edit, install, update, or removal, run `skill-sync`, then
`skill-sync --check`. Claude's `disable-model-invocation` header owns the
invocation policy; the command derives the per-skill Codex setting in
`agents/openai.yaml`. Other metadata remains hand-editable. Review and commit
skill, generated metadata, and lockfile changes together; commit external
changes in the owning repositories reported by the command.

Installation caveats and synchronization behavior live in `docs/agent-skills.md`.

## Cross-package features

Read the owning docs before changing a feature that spans packages:

- **Claude context chip** (`claude/`, `tmux/`, `zsh/`):
  `tmux/.config/tmux/workflow.md`. `tmux-claude-ctx.sh` alone turns pane
  borders off; weekly quota comes from headroom.
- **tmux pane control:** floating and relocation use
  `tmux/.config/tmux/scripts/float-pane.md`; pane-mode bindings and undo use
  `tmux/.config/tmux/scripts/pane-mode.md`.
- **Claude accounts:** `docs/claude-accounts.md`. The `x*` launchers in
  `zsh/.config/zsh/claude.zsh` delegate routing and validation to headroom
  (`~/dev/headroom`); engine fixes belong in that project.
- **Neovim-aware path copy** (`nvim/`, `tmux/`):
  `tmux/.config/tmux/workflow.md`. Neovim publishes the pane options;
  tmux reads them for `prefix y`/`Y`.

## Documentation

Keep one file per topic under `docs/`; inspect that directory before calling
something undocumented. Live docs describe current design and runbooks;
Git holds shipped proposals. `docs/documentation-standards.md` owns the shape
and checks for documentation changes.

Additional routes beyond the feature docs above:

- Auto-compaction settings: `docs/claude-autocompact.md`.
- Dormant Claude `cd` read guard: `docs/bypass-cd-read-guard.md`.
- The colleague's Mac mini (`ssh macmini`), including access etiquette:
  `docs/macmini.md`.
- tmux design-doc index: `tmux/.config/tmux/roadmap.md`.
- TabType prompt snippets: `tabtype/CLAUDE.md`.
