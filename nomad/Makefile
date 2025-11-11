# -------------------------------------------------------------------------------
# Nomad Service Pack - Makefile
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Build, test, and deploy automation for the nomad-service pack template
# -------------------------------------------------------------------------------

.DEFAULT_GOAL := help
.PHONY: help render test test-verbose test-all test-job test-category deploy \
        deploy-all deploy-category validate lint clean list format check \
        docs install uninstall

# -------------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------------

PACK_NAME := nomad-service
PACK_PATH := packs/registry/nomad-service
ROOT_PATH := .
JOBS_PATH := jobs
DEFAULTS := defaults.hcl
TEST_SCRIPT := ./test-pack.sh

# Colors for output
BOLD := \033[1m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# -------------------------------------------------------------------------------
# Help Target
# -------------------------------------------------------------------------------

help: ## Show this help message
	@echo "$(BOLD)Nomad Service Pack - Available Commands$(NC)"
	@echo ""
	@echo "$(BOLD)Testing:$(NC)"
	@grep -E '^test.*:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*##"}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BOLD)Deployment:$(NC)"
	@grep -E '^deploy.*:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*##"}; {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BOLD)Development:$(NC)"
	@grep -E '^(render|validate|lint|format|clean|list|docs):.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*##"}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BOLD)Examples:$(NC)"
	@echo "  make test                              # Test all jobs"
	@echo "  make test-job JOB=grafana              # Test specific job"
	@echo "  make test-category CAT=monitoring      # Test monitoring category"
	@echo "  make deploy-job JOB=grafana            # Deploy Grafana"
	@echo "  make render JOB=deluge                 # Render Deluge job"
	@echo ""

# -------------------------------------------------------------------------------
# Testing Targets
# -------------------------------------------------------------------------------

test: ## Run tests on all jobs (render only)
	@echo "$(BOLD)Testing all jobs...$(NC)"
	@$(TEST_SCRIPT)

test-verbose: ## Run tests with verbose output
	@echo "$(BOLD)Testing all jobs (verbose)...$(NC)"
	@$(TEST_SCRIPT) -v

test-all: test ## Alias for 'test'

test-job: ## Test a specific job (usage: make test-job JOB=grafana)
ifndef JOB
	@echo "$(YELLOW)Error: JOB parameter required$(NC)"
	@echo "Usage: make test-job JOB=grafana"
	@exit 1
endif
	@echo "$(BOLD)Testing job: $(JOB)$(NC)"
	@JOB_FILE=$$(find $(JOBS_PATH) -name "$(JOB).hcl" -type f | head -1); \
	if [ -z "$$JOB_FILE" ]; then \
		echo "$(YELLOW)Error: Job '$(JOB)' not found$(NC)"; \
		exit 1; \
	fi; \
	$(TEST_SCRIPT) $$JOB_FILE

test-category: ## Test all jobs in a category (usage: make test-category CAT=monitoring)
ifndef CAT
	@echo "$(YELLOW)Error: CAT parameter required$(NC)"
	@echo "Usage: make test-category CAT=monitoring"
	@exit 1
endif
	@echo "$(BOLD)Testing category: $(CAT)$(NC)"
	@if [ ! -d "$(JOBS_PATH)/$(CAT)" ]; then \
		echo "$(YELLOW)Error: Category '$(CAT)' not found$(NC)"; \
		exit 1; \
	fi; \
	$(TEST_SCRIPT) $(
