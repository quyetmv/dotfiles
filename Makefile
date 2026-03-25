# Ensure stable locale to avoid "cannot change locale" warnings
export LANG := C.UTF-8
export LC_ALL := C.UTF-8

.PHONY: help install sync apply devops-env linux test docker-test validate clean

help: ## Show this help message
	@echo "==========================================================="
	@echo "    dotfiles by quyetmv - Unified Command Center           "
	@echo "==========================================================="
	@echo "Usage: make [command]"
	@echo ""
	@echo "Commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

install: ## Run the initial dotfiles bootstrap process
	./scripts/bootstrap.sh

sync: ## Sync Homebrew and mise packages
	./scripts/sync-tooling.sh
	$(MAKE) apply

CHEZMOI_EXE := $(shell command -v chezmoi 2>/dev/null || echo ./bin/chezmoi)

apply: ## Apply dotfiles with Chezmoi
	$(CHEZMOI_EXE) apply --source $(PWD) --force

devops-env: ## Create or update ~/.devops-env with uv
	bash ./scripts/bootstrap-devops-env.sh

linux: ## Run the Linux-specific apt and setup tool
	./scripts/setup-linux.sh all

test: ## Run the local Chezmoi test suite
	CHEZMOI_SOURCE=$(PWD) ./scripts/test-chezmoi.sh

docker-test: ## Run the full validation in a clean Docker container
	./scripts/test-docker.sh --full

validate: ## Validate the applied configuration (run after install)
	./scripts/validate-setup.sh

backup-list: ## List available pre-sync snapshots
	@ls -lh ~/.dotfiles_backup/ 2>/dev/null || echo "No backups found."

restore-help: ## Show instructions on how to restore from backup
	@echo "To restore a file from Chezmoi backup:"
	@echo "  chezmoi merge <file-path>"
	@echo ""
	@echo "To restore a tool-versions or Brewfile snapshot:"
	@echo "  cp ~/.dotfiles_backup/<filename> <target-path>"

clean: ## Remove temporary files and cached test Data
	rm -rf .tmp/
