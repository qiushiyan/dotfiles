# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A **GNU Stow-managed dotfiles repository**. Each top-level directory is a Stow package that gets symlinked into `$HOME`. For example, `zsh/.zshrc` symlinks to `~/.zshrc`, and `nvim/.config/nvim/` symlinks to `~/.config/nvim/`. Editing files here directly modifies the user's live global config.

## Stow Commands

```bash
make install    # stow all packages (create symlinks)
make uninstall  # remove all symlinks
make restow     # re-stow after adding new files
make brew       # install Homebrew packages from Brewfile
make brew-dump  # export current Homebrew packages to Brewfile
```

## Structure

Each directory follows the Stow convention — its contents mirror the target path relative to `$HOME`:

| Package | Symlinks to | Purpose |
|---------|------------|---------|
| `zsh/` | `~/.zshrc`, `~/.zshenv`, `~/.config/zsh/` | Shell config, aliases, utilities |
| `git/` | `~/.gitconfig`, `~/.config/git/ignore` | Git config with conditional includes |
| `nvim/` | `~/.config/nvim/` | Neovim (LazyVim-based) |
| `ghostty/` | `~/.config/ghostty/` | Terminal emulator |
| `tmux/` | `~/.config/tmux/` | Tmux with catppuccin theme |
| `claude/` | `~/.claude/` | Claude Code global settings, skills, hooks |
| `codex/` | `~/.codex/` | Codex CLI config |
| `zed/` | `~/.config/zed/` | Zed editor settings |
| `karabiner/` | `~/.config/karabiner/` | Keyboard remapping |
| `k9s/` | `~/.config/k9s/` | Kubernetes TUI |
| `ssh/` | `~/.ssh/config` | SSH hosts and keys |
| `raycast/` | Raycast scripts | macOS automation |
| `ohmyposh/` | `~/.config/ohmyposh/` | Prompt theme |

## Zsh Module Layout

Shell config is split across `zsh/.config/zsh/`:

- `aliases.zsh` — All shell aliases (editors, git, k8s, dev servers)
- `git.zsh` — Git helper functions (`gitclean`, `gitgc`, `stage`)
- `nav.zsh` — Navigation (`n`, `take`, `drop`, `y` for yazi, `fcd`)
- `utils.zsh` — Utilities (`ccclean`, `loc`, `dotadd`, proxy toggles)
- `xcode.zsh` — Xcode build/test helpers for TabType

These are all sourced by `.zshenv` via a glob: `source ~/.config/zsh/*.zsh`.

## Key Conventions

- **Theme**: Catppuccin Mocha across all tools (ghostty, tmux, nvim, k9s)
- **Editor**: Neovim is the default (`core.editor = nvim` in gitconfig), vim keybindings everywhere
- **Package manager**: pnpm preferred over npm (enforced via Claude Code hook in `claude/.claude/hooks/block-npm.sh`)
- **Python**: 3.14 (`/opt/homebrew/bin/python3.14`), aliased as both `python` and `python3`
- **Node**: Managed via nvm, default v22
- **Adding new dotfiles**: Use the `dotadd` shell function to copy a config file into the correct Stow package path

## Important: Stow Awareness

When editing files in this repo, remember that changes take effect immediately on the live system (files are symlinked, not copied). The `claude/` directory here **is** `~/.claude/` — settings edited here are the user's global Claude Code config.
