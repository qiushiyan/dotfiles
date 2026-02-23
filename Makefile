PACKAGES := $(sort $(dir $(wildcard */)))

install: ## Stow all packages
	stow $(PACKAGES)

uninstall: ## Unstow all packages
	stow -D $(PACKAGES)

restow: ## Re-stow all packages (useful after adding new files)
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
