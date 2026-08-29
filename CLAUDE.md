# CLAUDE.md

## What this is

A **GNU Stow-managed dotfiles repository**: each top-level directory is a
package whose tree mirrors `$HOME` (`zsh/.zshrc` → `~/.zshrc`,
`nvim/.config/nvim/` → `~/.config/nvim/`). Files are **symlinked, not
copied — an edit here changes the live system immediately.** `docs/` and
`vpn-private/` are the only directories never stowed.

The repo is **public**. Secrets live in `~/.secrets` (untracked, sourced by
`.zshrc`); tracked config reads them from the environment.

## Red lines

Three ways to wreck live state; none raises an error at the time.

1. **`~/.claude`, `~/.codex`, `~/.config/lazygit` stay real directories, never
   folded symlinks.** Tracked config is linked in per item; runtime state
   (`auth.json`, sessions) stays in `~/` and out of this public repo. Before
   changing `make install` or the `.gitignore` allow-lists that defend this →
   `docs/stow-layout.md`.
2. **`claude/.claude/CLAUDE.md` stays empty.** It stows to `~/.claude/CLAUDE.md`,
   the global memory prepended to every request in every project. Any other
   `<pkg>/CLAUDE.md` stows to `~/CLAUDE.md` with the same reach unless the
   package's `.stow-local-ignore` excludes it (`tabtype/` does); Claude
   configuration is documented in `docs/`.
3. **A test that escapes its sandbox corrupts live state**, and a green suite
   that tested nothing looks like a passing one → `docs/testing.md` before
   adding a case.

## Working here

- Edits are live; no build. `make restow` only after adding or removing a
  file; `dotadd <path>` brings an unmanaged file under a package.
- Commit directly on `main`; pushes to `main` are the user's to run.
- **"What's my shortcut / how do I…"** is a read: the tool's config plus
  `tmux/.config/tmux/workflow.md`; nothing is edited.
- **Adding or porting a theme** (recurring): `docs/theming.md` is the
  recipe. One `$TERMINAL_THEME` value fans out to several per-tool files, so
  a theme is done when every surface the doc lists has one.
- **Editing `zsh/`** startup order, anything `.zshrc` sources, or a shell
  slowness complaint → `docs/zsh.md` first (`python` and `make` are
  functions; nvm is lazy-loaded).
- **Skill, lesson, or agent-doc work** — the most common task here. The
  session loop is `docs/doc-loop.md`; which of the four ownership tiers a
  skill is in decides whether its body may be edited and where a rule lands
  → `docs/agent-skills.md`. Installing from the `skills` CLI, the only form
  that works in this repo:

  ```bash
  npx skills add <owner/repo@skill> -g -a claude-code --copy -y   # real dir, Claude only
  npx skills update <name> -g -y     # one skill at a time; it re-creates a dangling
                                     # ../../.agents/skills/<name> link — recovery in agent-skills.md
  ```

  Codex gets a skill only by a relative symlink from `codex/.codex/skills/`
  added by hand; never `-a codex`.

## Package layout

`make list` plus the tree answers most questions. The ones whose contents
aren't obvious from the name:

```
claude/    ~/.claude/           settings.json, hooks, skills, agents, commands, rules
codex/     ~/.codex/            Codex CLI config; its skills symlink into claude/
zsh/       ~/.zshrc, ~/.zshenv, ~/.config/zsh/
tmux/      ~/.config/tmux/      tmux 3.7b — scripts, plugins, design docs
nvim/      ~/.config/nvim/      LazyVim-based
tabtype/   ~/.config/tabtype/   the ;; prompt snippets — its own CLAUDE.md + WORKFLOW.md
lessons/   ~/.config/lessons/   durable rules skills and snippets point at; not skills
scripts/   ~/.local/bin/, ~/Library/LaunchAgents/
```

## Cross-package features

One feature, several packages; editing one side without the other breaks it.

- **Claude context chip** (`claude/`, `tmux/`, `zsh/`) — account, quota, model,
  context on the pane border; `tmux-claude-ctx.sh` alone turns borders off →
  `tmux/.config/tmux/workflow.md`; the weekly quota comes from `headroom` →
  `docs/claude-accounts.md`.
- **tmux pane control** — `prefix z` floats, `prefix Z` scratch popup,
  `prefix p` moves; a float relocates the pane into a holder session, so read
  `tmux/.config/tmux/scripts/float-pane.md` before touching
  `tmux-float-pane.sh`, `tmux-pane-relocate.sh`, or the pane/float key tables.
- **Claude accounts** — the `x*` launchers in `zsh/.config/zsh/claude.zsh` wrap
  headroom (`~/dev/headroom`) and ccclean (`~/dev/ccclean`), which live outside
  this repo and are usually where a fix belongs → `docs/claude-accounts.md`.
- **Neovim-aware path copy** (`nvim/`, `tmux/`) — `prefix y`/`Y`; Neovim sets
  the pane options, tmux only reads them → `tmux/.config/tmux/workflow.md`.

## Docs

```
docs/doc-loop.md               the session loop (onboarding → consult/review → update-docs → handoff)
docs/agent-skills.md           skill ownership tiers · Claude ⊇ Codex layout · lessons
docs/theming.md                themes
docs/claude-accounts.md        accounts
docs/zsh.md                    shell
tmux/.config/tmux/workflow.md  tmux day to day; roadmap.md indexes the tmux design docs
```

One file per topic under `docs/` (`ls docs/` before calling something
undocumented); `docs/superpowers/` is dated history, not live. Each doc routes
to its own satellites.
