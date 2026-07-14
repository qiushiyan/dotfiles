# Not every top-level dir is a stow package — filter out the repo-only ones so
# `install`/`restow` never symlinks them into $HOME:
#   vpn-private/  local backup/handoff folder (gitignored)
#   docs/         repo documentation, lives here only
PACKAGES := $(filter-out vpn-private/ docs/,$(sort $(dir $(wildcard */))))

# Dirs that must exist as REAL directories before stowing, so stow folds only
# the tracked config inside them (per-item symlinks) instead of replacing the
# whole dir with one folded symlink. This keeps each app's runtime state
# (Claude history/sessions/telemetry; Codex sqlite/sessions/auth.json, etc.)
# in the real ~/dir, out of this repo.
REAL_DIRS := $(HOME)/.claude $(HOME)/.codex

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
