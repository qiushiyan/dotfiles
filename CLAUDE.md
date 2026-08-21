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

**1. `~/.claude`, `~/.codex` and `~/.config/lazygit` must stay real
directories, never folded symlinks.** Only tracked config is symlinked in,
per item; everything the apps write at runtime stays in the real `~/` directory
and out of this public repo — `~/.codex/auth.json` included. `make install`
and the `.gitignore` allow-lists both defend it → `docs/stow-layout.md`.

**2. Never write to `claude/.claude/CLAUDE.md` — it is empty, and stays empty.**
It looks package-local; it is not. It stows to `~/.claude/CLAUDE.md`, the
**global** memory prepended to every request in _every_ project on this machine.
Document Claude configuration in a `docs/` file instead. Any `<pkg>/CLAUDE.md`
has the same reach → `docs/stow-layout.md`.

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

No build — this is configuration. Tests: `docs/testing.md`. To bring a new file
under management use the `dotadd` zsh function rather than moving it by hand.

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

Every other package is one tool's config at its conventional path.

## Conventions

- **Theme**: `$TERMINAL_THEME`, read from `~/.config/terminal-theme`, drives the
  Claude statusline, Oh My Posh prompt, `ls`/completion colors and the Neovim
  colorscheme; Ghostty/tmux/k9s are themed per-tool. See `docs/theming.md` for
  the supported values and how to add one.
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

- **Claude context chip** — a live Claude session's account, that account's
  5-hour and model-scoped-weekly quota, its model and context
  usage on its tmux pane border. Spans `claude/`, `tmux/`, `zsh/`;
  `tmux-claude-ctx.sh` is the sole owner of turning borders off →
  `tmux/.config/tmux/workflow.md`. Everything but the weekly comes off the
  payload Claude Code hands the statusline; the weekly is the one value that
  reaches outside this repo, to `headroom limits` →
  `docs/claude-accounts.md`.
- **tmux pane control** — `prefix z` floats a pane into an overlay rather than
  zooming it; `prefix Z` opens an ephemeral scratch popup at the pane's cwd;
  `prefix p` holds the pane-moving verbs. A float genuinely
  relocates the pane into a holder session, which is why so much hangs off it.
  **Read `tmux/.config/tmux/scripts/float-pane.md` before editing
  `tmux-float-pane.sh`, `tmux-pane-relocate.sh`, or the pane/float key tables.**
- **Claude accounts** — several subscriptions coexist (`~/.claude` primary,
  extras under `~/.claude-accounts/<email>/`, all runtime state that never
  enters this repo). The `x*` launchers in `zsh/.config/zsh/claude.zsh` are thin
  wrappers over two engines that live **outside** this repo — headroom
  (`~/dev/headroom`) and ccclean (`~/dev/ccclean`) — so that is usually where a
  fix belongs → `docs/claude-accounts.md`.
- **Neovim-aware path copy** — tmux `prefix y`/`Y` copy the file focused in
  Neovim (absolute/relative), falling back to the pane cwd. Neovim pushes the
  answer into pane-scoped `@yank_path`/`@yank_path_rel` options (`TmuxYankPath`
  block in `nvim` `autocmds.lua`); the tmux bindings are pure format
  conditionals and know nothing about nvim. Spans `nvim/`, `tmux/` →
  `tmux/.config/tmux/workflow.md` (Quick helpers).
- **Agent skills** — Claude Code is a superset of Codex, which symlinks into it.
  Adding, forking, or disabling a skill has several traps that fail silently →
  `docs/agent-skills.md`.

## Where to read more

```
docs/
  stow-layout.md          what gets symlinked, and what must stay real
  zsh.md                  shell architecture, module map, perf lessons
  agent-skills.md         the Claude ⊇ Codex skill layout and its traps
  testing.md              the test suites and their sandbox rules
  claude-accounts.md      multi-account setup
  theming.md              the $TERMINAL_THEME switch
  ghostty-fonts.md        why bold barely reads, why 汉字 render small
  tmux-popup-patch.md     why tmux is a patched local-tap formula, not stock
  doc-loop.md             the session loop: onboarding → consult/spike/review
                          → update-docs → handoff
  MIGRATION.md            new-machine setup
  mobile-terminal-access.md   phone → Mac over Tailscale + mosh
  ctrl-d-guard.md · claude-prompt-completion.md
  neovim-file-picker.md · neovim-image-handling.md · neovim-diagnostics.md
  superpowers/            dated specs and plans — history, not live docs
tmux/.config/tmux/
  workflow.md             how the tmux setup is meant to be used day to day
  roadmap.md              index of the tmux design docs
  scripts/                float-pane.md · worktree.md · agent-notify.md
```

Each doc routes to its own satellites; this map lists only the entry points.
