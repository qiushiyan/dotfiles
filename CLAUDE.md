# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A **GNU Stow-managed dotfiles repository**. Each top-level directory is a Stow package whose contents mirror a path under `$HOME` — e.g. `zsh/.zshrc` → `~/.zshrc`, `nvim/.config/nvim/` → `~/.config/nvim/`. Files are **symlinked, not copied: editing anything here changes the user's live system immediately.** The `claude/` package holds the user's global Claude Code config — `settings.json`, `hooks/`, `skills/`, `agents/`, `commands/`, `rules/`, `CLAUDE.md`.

**`~/.claude` and `~/.codex` are real directories, not folded symlinks.** Only the tracked config items are symlinked in from their packages (per-item folding); everything the apps write at runtime — Claude's `history.jsonl`, `sessions/`, `projects/`, `telemetry/`; Codex's sqlite DBs, `sessions/`, the `auth.json` secret, caches — stays in the real `~/dir` and never enters this repo. `make install`/`restow` `mkdir -p` these first to preserve it (see `REAL_DIRS` in the Makefile); both `.gitignore` blocks allow-list only config as defense-in-depth. **Do not** let either become a single symlink to its package, or all that runtime state (and `~/.codex/auth.json`) lands in this public repo.

This repo is **public** — never commit credentials (see Secrets below).

## Commands

```bash
make install    # stow all packages (create symlinks)
make restow     # re-stow after adding/removing files
make uninstall  # remove all symlinks
make list       # list stow packages
make brew       # install Homebrew packages from Brewfile
make brew-dump  # update Brewfile from current Homebrew state
```

There is no build or test suite — this is configuration. To bring an existing config file under management, use the `dotadd` zsh function (it moves the file into the correct package and stows it).

## Stow Package Layout

Each directory's contents mirror the target path relative to `$HOME`:

| Package | Symlinks to | Purpose |
|---------|------------|---------|
| `zsh/` | `~/.zshrc`, `~/.zshenv`, `~/.config/zsh/` | Shell config, aliases, functions |
| `git/` | `~/.gitconfig`, `~/.config/git/ignore` | Git config with conditional includes |
| `nvim/` | `~/.config/nvim/` | Neovim (LazyVim-based) |
| `ghostty/`, `tmux/` | `~/.config/{ghostty,tmux}/` | Terminal + multiplexer |
| `claude/` | `~/.claude/` | Claude Code settings, skills, hooks |
| `codex/` | `~/.codex/` | Codex CLI config |
| `ohmyposh/` | `~/.config/ohmyposh/` | Prompt theme |
| `zed/`, `k9s/`, `karabiner/`, `ssh/`, `raycast/` | resp. paths | Editor, k8s TUI, key remap, SSH, automation |

`make list` shows the full set.

## Zsh Architecture

Three startup files, each for a different shell type — know which one a change belongs in:

- **`.zshenv`** — *every* zsh invocation (incl. scripts, `ssh host cmd`). Sets `typeset -U path`, sources `toolchain.zsh`, then sources every `~/.config/zsh/*.zsh` so functions/aliases exist everywhere.
- **`.zprofile`** — login shells only. Homebrew + OrbStack `shellenv`.
- **`.zshrc`** — interactive shells only. oh-my-zsh, syntax highlighting, completions, Oh My Posh prompt, fzf/zoxide, the lazy `nvm` stub.

They load in the order `.zshenv` → `.zprofile` → `.zshrc`. The order matters: `.zprofile`'s Homebrew `shellenv` runs *after* `toolchain.zsh`, so `.zshrc` re-asserts `$NVM_BIN` to keep nvm's Node ahead of any Homebrew `node`.

Modules in `zsh/.config/zsh/`:

- `toolchain.zsh` — cheap PATH setup (default Node via nvm, no subprocess) for non-interactive shells; sourced first by `.zshenv`.
- `aliases.zsh`, `git.zsh`, `nav.zsh`, `utils.zsh` — aliases and helper functions (`gitclean`, `loc`, `ccclean`, `n`, `take`, `dotadd`, …).
- `theme.zsh` — the `$TERMINAL_THEME` switch.
- `xcode.zsh`, `tmux-utils.zsh`, `proxy.zsh`, `gws.zsh` — domain-specific helpers.

## Key Conventions

- **Theme**: `$TERMINAL_THEME` (from `~/.config/terminal-theme`, default `flexoki_light`; also `catppuccin_mocha`) drives the Claude Code statusline, Oh My Posh prompt, `ls`/completion colors, and the Neovim colorscheme. Ghostty/tmux/k9s themes are set per-tool.
- **Editor**: Neovim (LazyVim-based); vim keybindings everywhere, `set -o vi` in zsh.
- **Package manager**: pnpm preferred over npm.
- **Python**: `python` is a *function* → `command python3` (Homebrew's), so virtualenvs still win — not an alias (see lessons).
- **Node**: nvm, default `lts/*`, **lazy-loaded** (see lessons).
- **Secrets**: live in `~/.secrets` (untracked, mode `600`, sourced by `.zshrc`). Tracked config reads them from the environment instead of hardcoding.
- **`block-dangerous-git.sh`** (Claude Code hook in `claude/.claude/hooks/`) blocks `push` / `reset --hard` / etc. on `main` — pushes to `main` must be run by the user manually, not by Claude.

## Zsh Setup: Lessons Learned

Hard-won during a startup-perf + robustness pass — read before editing the zsh config:

- **Reload with `exec zsh`, never `source ~/.zshrc`.** Re-sourcing only *adds* state; it can't drop deleted aliases/functions/exports or fix stale in-memory state. `zshreload` is aliased to `exec zsh -l`.
- **`.zshenv` must exit 0.** A non-zero last statement silently breaks `source ~/.zshenv && …` chains. Keep the final line a clean `if`, not a short-circuiting `&&`.
- **nvm is lazy-loaded.** Eagerly sourcing `nvm.sh` costs ~230 ms/shell. `toolchain.zsh` already puts the default Node on PATH cheaply; an `nvm()` stub in `.zshrc` loads the real nvm on first call. Don't reinstate eager `source nvm.sh`.
- **`typeset -U path`** (in `.zshenv`) keeps `$PATH` duplicate-free no matter how often config is sourced.
- **Functions, not aliases, for real command names.** Aliases resolve before `$PATH`, so `alias python=…` shadows virtualenvs; `python` and `make` are functions for this reason. Start non-trivial functions with `emulate -L zsh` so ambient options can't change their behavior.
- **Completions register late.** `compdef` exists only after oh-my-zsh runs `compinit`. `git.zsh` is sourced once (by `.zshenv`); `.zshrc` calls `_git_zsh_register_completions` afterward — don't re-source whole files just to register completions.
- **Measure, don't guess.** Profile with `zmodload zsh/zprof`; verify a perf change with an *interleaved* A/B benchmark (`git stash` the change, time both back-to-back, repeat) — not before/after numbers taken minutes apart. This pass took startup ~530 ms → ~160 ms.
