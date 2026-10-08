# Not every top-level dir is a stow package — filter out the repo-only ones so
# `install`/`restow` never symlinks them into $HOME:
#   vpn-private/  credentials live in the password manager; a copy restored
#                 here is never stowed (docs/recovery.md)
#   docs/         repo documentation, lives here only
#   references/   repo-only reading, opened at ~/dotfiles/references
#   node_modules/ the root package.json's install, gitignored
#   launchd-*/    one package of launchd agents per machine: only the one
#                 ~/.config/machine names is stowed, and none without a marker
MACHINE := $(shell cat $(HOME)/.config/machine 2>/dev/null | tr -d '[:space:]')
OTHER_LAUNCHD := $(filter-out launchd-$(MACHINE)/,$(wildcard launchd-*/))
PACKAGES := $(filter-out vpn-private/ docs/ references/ node_modules/ $(OTHER_LAUNCHD),$(sort $(dir $(wildcard */))))

# Dirs that must exist as REAL directories before stowing, so stow folds only
# the tracked config inside them (per-item symlinks) instead of replacing the
# whole dir with one folded symlink. This keeps each app's runtime state
# (Claude history/sessions/telemetry; Codex sqlite/sessions/auth.json;
# lazygit state.yml, etc.) in the real ~/dir, out of this repo.
REAL_DIRS := $(HOME)/.claude $(HOME)/.codex $(HOME)/.agents $(HOME)/.config/lazygit $(HOME)/.config/rex

install: ## Stow all packages
	@mkdir -p $(REAL_DIRS)
	stow $(PACKAGES)

uninstall: ## Unstow all packages
	stow -D $(PACKAGES)

restow: ## Re-stow all packages (useful after adding new files)
	@mkdir -p $(REAL_DIRS)
	stow -R $(PACKAGES)

brew: ## Install Homebrew packages from Brewfile
	brew bundle --file=Brewfile

brew-dump: ## Update Brewfile with current Homebrew packages
	brew bundle dump --file=Brewfile --force

list: ## List all stow packages
	@echo $(PACKAGES)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: install uninstall restow brew brew-dump list help
