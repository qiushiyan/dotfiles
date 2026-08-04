# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **GNU Stow-managed dotfiles repository**. Each top-level directory is a Stow
package whose contents mirror a path under `$HOME` — `zsh/.zshrc` → `~/.zshrc`,
`nvim/.config/nvim/` → `~/.config/nvim/`. Files are **symlinked, not copied:
editing anything here changes the user's live system immediately.** `docs/`
(repo-only documentation) and `vpn-private/` (gitignored local backup) are
filtered out of `PACKAGES` in the Makefile and never symlinked.

This repo is **public** — never commit credentials. Secrets live in `~/.secrets`
(untracked, mode `600`, sourced by `.zshrc`); tracked config reads them from the
environment instead of hardcoding.

## Red lines

Three ways to wreck live state from inside this repo. None of them raise an
error at the time.

**1. `~/.claude` and `~/.codex` must stay real directories, never folded
symlinks.** Only tracked config items are symlinked in from their packages
(per-item folding); everything the apps write at runtime — Claude's
`history.jsonl`, `sessions/`, `projects/`, `telemetry/`; Codex's sqlite DBs,
`sessions/`, the `auth.json` secret, caches — stays in the real `~/` directory
and never enters this repo. `make install`/`restow` `mkdir -p` them first to
preserve this (`REAL_DIRS` in the Makefile), and both `.gitignore` blocks
allow-list only config as defense-in-depth. Let either become a single symlink
to its package and all that runtime state, `~/.codex/auth.json` included, lands
in this public repo.

**2. Never write to `claude/.claude/CLAUDE.md` — it is empty, and stays empty.**
It reads like a project-local memory file describing this repo's `claude/`
package. It is not. It stows to `~/.claude/CLAUDE.md`, the **global** user
memory, which is prepended to every request in _every_ project on this machine.
Notes about this repo's layout, or about how Claude is configured here, become
permanent context for unrelated work everywhere. To document Claude
configuration, write an ordinary doc under `docs/` and link it from the map
below.

The same hazard exists at any package root, since `<pkg>/CLAUDE.md` stows to
`~/CLAUDE.md`: `tabtype/CLAUDE.md` is package-local guidance kept out of `$HOME`
by an entry in `tabtype/.stow-local-ignore`. Package-local guidance needs that
ignore entry; the global memory file needs to stay empty.

**3. A test that escapes its sandbox corrupts live state.** Both escape routes
are silent, and a green suite that tested nothing looks identical to a passing
one — read `docs/testing.md` before adding a case.

## Commands

```bash
make install    # stow all packages (create symlinks)
make restow     # re-stow after adding/removing files
make uninstall  # remove all symlinks
make list       # list stow packages
make brew       # install Homebrew packages from Brewfile
make brew-dump  # update Brewfile from current Homebrew state
```

This is configuration, so there is no build. Tests: `docs/testing.md`.

To bring an existing config file under management, use the `dotadd` zsh function
— it moves the file into the correct package and stows it.

## Package layout

A package's internal tree _is_ its map of `$HOME`, so `make list` plus the
directory itself answers most questions. The ones whose contents aren't obvious
from the name:

```
claude/    ~/.claude/           settings.json, hooks, skills, agents, commands, rules
codex/     ~/.codex/            Codex CLI config; its skills symlink into claude/
zsh/       ~/.zshrc, ~/.zshenv, ~/.config/zsh/
tmux/      ~/.config/tmux/      tmux 3.7b — scripts, plugins, design docs
nvim/      ~/.config/nvim/      LazyVim-based
lessons/   ~/.config/lessons/   engineering reference docs that prompts read — not skills
scripts/   ~/.local/bin/, ~/Library/LaunchAgents/
```

The rest — `git/`, `ghostty/`, `ohmyposh/`, `zed/`, `k9s/`, `lazygit/`,
`karabiner/`, `ssh/`, `raycast/`, `tabtype/` — is one tool's config at its
conventional path.

## Conventions

- **Theme**: `$TERMINAL_THEME` (from `~/.config/terminal-theme`, default
  `flexoki_light`; also `catppuccin_mocha`) drives the Claude statusline, Oh My
  Posh prompt, `ls`/completion colors, and the Neovim colorscheme.
  Ghostty/tmux/k9s are themed per-tool. See `docs/theming.md`.
- **Editor**: Neovim (LazyVim-based); vim keybindings everywhere, `set -o vi`.
- **Shell**: three startup files with a load-bearing order, nvm lazy-loaded,
  `python` and `make` are functions rather than aliases. Read `docs/zsh.md`
  before editing anything under `zsh/`.
- **`block-dangerous-git.sh`** (hook in `claude/.claude/hooks/`) blocks `push`,
  `reset --hard`, and similar on `main`. Pushes to `main` are the user's to run
  manually, not Claude's.
- **Development**: this is personal configuration — commit directly on `main`
  and don't create feature branches unless asked.

## Features that span packages

Each of these is one feature implemented across several packages at once;
changing one piece without the others breaks it.

- **Claude context chip** — the statusline script pushes context-usage % into the
  pane-local `@claude_ctx` tmux option, the pane border draws it, and
  `tmux-claude-ctx.sh` is the sole owner of turning borders off (fed by Claude's
  `SessionEnd` hook, a zsh `precmd` sweep, and tmux pane-exit/relocation
  events). Spans `claude/`, `tmux/`, `zsh/` → `tmux/.config/tmux/workflow.md`.
- **tmux pane control** — `prefix z` floats a pane into an overlay rather than
  zooming it; `prefix p` holds the pane-moving verbs in a sticky key table. A
  floated pane is genuinely relocated into a holder session, so its recovery,
  its restricted key surface, and the resurrect save wrapper are all
  load-bearing. **Read `tmux/.config/tmux/scripts/float-pane.md` before editing
  `tmux-float-pane.sh`, `tmux-pane-relocate.sh`, or the pane/float key tables in
  `tmux.conf`.**
- **Claude accounts** — several subscriptions coexist: `~/.claude` is primary,
  each extra is `~/.claude-accounts/<email>/` with its own Keychain login.
  Launchers (`x`, `x-<name>`, `x-acc`, `x-select`) live in
  `zsh/.config/zsh/claude.zsh` but are thin wrappers over **headroom**, a Go
  CLI in `~/dev/headroom`, which owns the usage board, the session picker,
  and launch routing itself (`headroom launch` builds `CLAUDE_CONFIG_DIR`
  from the validated choice; wrappers never touch it) — so fix the engine
  there. Session transcripts are machine-global (every account's `projects/`
  symlinks to `~/.claude/projects`, enforced at launch; toolkit in
  `zsh/.config/zsh/claude-sessions.zsh`). Account dirs are runtime state,
  never in this repo → `docs/claude-accounts.md`.
- **Agent skills** — Claude Code is a superset of Codex, which symlinks into it.
  Adding, forking, or disabling a skill has several traps that fail silently →
  `docs/agent-skills.md`.

## Where to read more

```
docs/
  zsh.md                  shell architecture, module map, perf lessons
  agent-skills.md         the Claude ⊇ Codex skill layout and its traps
  testing.md              the two suites and their sandbox rules
  claude-accounts.md      multi-account setup
  theming.md              the $TERMINAL_THEME switch
  doc-loop.md             the session loop end to end: onboarding, the
                          consult → spike → build → review middle, handoff
  MIGRATION.md            new-machine setup
  ctrl-d-guard.md · claude-prompt-completion.md
  neovim-file-picker.md · neovim-image-handling.md
  mobile-terminal-access.md
tmux/.config/tmux/
  workflow.md             how the tmux setup is meant to be used day to day
  roadmap.md              index of the tmux design docs
  scripts/                float-pane.md · worktree.md · agent-notify.md
```
