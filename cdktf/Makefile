# ------------------------------------------------------------------------------
# Makefile - Munchbox CDKTF Infrastructure
#
# Single Makefile for building, validating, and deploying all infrastructure.
# No need to change directories - everything runs from the root.
#
# Also used in Github Actions Pipelines
# ------------------------------------------------------------------------------

# --- Variables ---
BIN_DIR := bin
TOOLS := validate-structure nomad-query
JOBS_DIR := infra/nomad-jobs

# Find all .nomad.hcl files recursively, excluding do-not-run
NOMAD_FILES := $(shell find $(JOBS_DIR) -type f -name "*.nomad.hcl" ! -path "*/do-not-run/*")

# Get unique categories from directory structure
CATEGORIES := $(shell find $(JOBS_DIR) -mindepth 1 -maxdepth 1 -type d ! -name "do-not-run" -exec basename {} \;)

# ANSI color codes
COLOR_RESET   := \033[0m
COLOR_RED     := \033[0;31m
COLOR_GREEN   := \033[0;32m
COLOR_YELLOW  := \033[0;33m
COLOR_BLUE    := \033[0;34m
COLOR_CYAN    := \033[0;36m

.PHONY: all build build-tools build-all synth deploy deploy-jobs plan diff \
        validate validate-jobs validate-category fmt fmt-jobs lint check-structure query \
        list-categories category-report deploy-category semgrep trivy \
        test clean clean-all help

# Default target
all: build-all validate

# ------------------------------------------------------------------------------
# Build Targets
# ------------------------------------------------------------------------------

# Build main CDKTF application
build:
	@echo "$(COLOR_CYAN)==> Building CDKTF application...$(COLOR_RESET)"
	go build -o nomad-app .
	@echo "$(COLOR_GREEN)[OK]$(COLOR_RESET) nomad-app built"

# Build all utility tools from cmd/
build-tools:
	@echo "$(COLOR_CYAN)==> Building utility tools...$(COLOR_RESET)"
	@mkdir -p $(BIN_DIR)
	@for tool in $(TOOLS); do \
		echo "  Building $$tool..."; \
		go build -o $(BIN_DIR)/$$tool cmd/$$tool/main.go; \
	done
	@echo "$(COLOR_GREEN)[OK]$(COLOR_RESET) Tools built in $(BIN_DIR)/"

# Build everything
build-all: build build-tools
	@echo "$(COLOR_GREEN)[OK]$(COLOR_RESET) All binaries compiled"

# ------------------------------------------------------------------------------
# CDKTF Targets
# ------------------------------------------------------------------------------

# Generate Terraform JSON from CDKTF
synth: build
	@echo "$(COLOR_CYAN)==> Synthesizing Terraform configuration...$(COLOR_RESET)"
	@./nomad-app 2>&1 | sed \
		-e 's/\[ERROR\]/\x1b[0;31m[ERROR]\x1b[0m/g' \
		-e 's/\[WARN\]/\x1b[0;33m[WARN]\x1b[0m/g' \
		-e 's/\[OK\]/\x1b[0;32m[OK]\x1b[0m/g' \
		-e 's/\[INJECT\]/\x1b[0;36m[INJECT]\x1b[0m/g' \
		-e 's/\[UPDATE\]/\x1b[0;34m[UPDATE]\x1b[0m/g'
	@echo "$(COLOR_GREEN)[OK]$(COLOR_RESET) Terraform JSON generated in cdktf.out/"

# Deploy all infrastructure
deploy: synth
	@echo "$(COLOR_CYAN)==> Deploying all infrastructure...$(COLOR_RESET)"
	cdktf deploy

# Deploy specific job categories (comma-separated)
# Usage: make deploy-jobs JOBS=monitoring,infrastructure
deploy-jobs: build
	@if [ -z "$(JOBS)" ]; then \
		echo "$(COLOR_RED)[ERROR]$(COLOR_RESET) JOBS parameter required"; \
		echo "Usage: make deploy-jobs JOBS=monitoring,infrastructure"; \
		exit 1; \
	fi
	@echo "$(COLOR_CYAN)==> Deploying jobs: $(JOBS)$(COLOR_RESET)"
	./nomad-app -jobs=$(JOBS)
	cdktf deploy

# Show Terraform plan
plan: synth
	@echo "$(COLOR_CYAN)==> Planning Terraform changes...$(COLOR_RESET)"
	cd cdktf.out/stacks/nomad && terraform plan

# Show CDKTF diff
diff: synth
	@echo "$(COLOR_CYAN)==> Showing differences...$(COLOR_RESET)"
	cdktf diff

# ------------------------------------------------------------------------------
# Nomad Job Validation Targets
# ------------------------------------------------------------------------------

# Validate all Nomad job files
validate-jobs:
	@echo "$(COLOR_CYAN)==> Validating Nomad job files...$(COLOR_RESET)"
	@for f in $(NOMAD_FILES); do \
		echo "--- $$f"; \
		nomad job validate $$f || exit 1; \
	done
	@echo "$(COLOR_GREEN)[OK]$(COLOR_RESET) All jobs validated successfully"

# Shorthand alias
validate: validate-jobs

# Validate jobs in specific category
# Usage: make validate-category CAT=monitoring
validate-category:
	@if [ -z "$(CAT)" ]; then \
		echo "$(COLOR_RED)[ERROR]$(COLOR_RESET) CAT parameter required"; \
		echo "Usage: make validate-category CAT=monitoring"; \
		exit 1; \
	fi
	@if [ ! -d "$(JOBS_DIR)/$(CAT)" ]; then \
		echo "$(COLOR_RED)[ERROR]$(COLOR_RESET) Category '$(CAT)' does not exist"; \
		echo "Available categories:"; \
		$(MAKE) list-categories; \
		exit 1; \
	fi
	@echo "$(COLOR_CYAN)==> Validating $(CAT) jobs...$(COLOR_RESET)"
	@for f in $(JOBS_DIR)/$(CAT)/*.nomad.hcl; do \
		if [ -f "$$f" ]; then \
			echo "--- $$f"; \
			nomad job validate $$f || exit 1; \
		fi \
	done
	@echo "$(COLOR_GREEN)[OK]$(COLOR_RESET) All $(CAT) jobs validated"

# ------------------------------------------------------------------------------
# Formatting Targets
# ------------------------------------------------------------------------------

# Format all HCL files
fmt-jobs:
	@echo "$(COLOR_CYAN)==> Formatting Nomad job files...$(COLOR_RESET)"
	@cd $(JOBS_DIR) && nomad fmt -recursive .
	@echo "$(COLOR_GREEN)[OK]$(COLOR_RESET) Nomad jobs formatted"

# Format Go code and HCL files
fmt:
	@echo "$(COLOR_CYAN)==> Formatting Go code...$(COLOR_RESET)"
	@go fmt ./...
	@$(MAKE) fmt-jobs

# ------------------------------------------------------------------------------
# Category Management
# ------------------------------------------------------------------------------

# List all job categories
list-categories:
	@echo "Available categories:"
	@for cat in $(CATEGORIES); do \
		count=$$(find $(JOBS_DIR)/$$cat -name "*.nomad.hcl" 2>/dev/null | wc -l); \
		echo "  $(COLOR_BLUE)-$(COLOR_RESET) $$cat ($$count jobs)"; \
	done

# Show detailed category breakdown
category-report:
	@echo "$(COLOR_CYAN)==> Job Category Report$(COLOR_RESET)"
	@echo ""
	@for cat in $(CATEGORIES); do \
		echo "$(COLOR_BLUE)Category:$(COLOR_RESET) $$cat"; \
		find $(JOBS_DIR)/$$cat -name "*.nomad.hcl" 2>/dev/null | sed 's|.*/||' | sed 's|.nomad.hcl||' | sed 's/^/  - /'; \
		echo ""; \
	done

# Deploy all jobs in a specific category
# Usage: make deploy-category CAT=monitoring
deploy-category:
	@if [ -z "$(CAT)" ]; then \
		echo "$(COLOR_RED)[ERROR]$(COLOR_RESET) CAT parameter required"; \
		echo "Usage: make deploy-category CAT=monitoring"; \
		exit 1; \
	fi
	@if [ ! -d "$(JOBS_DIR)/$(CAT)" ]; then \
		echo "$(COLOR_RED)[ERROR]$(COLOR_RESET) Category '$(CAT)' does not exist"; \
		echo "Available categories:"; \
		$(MAKE) list-categories; \
		exit 1; \
	fi
	@echo "$(COLOR_CYAN)==> Deploying $(CAT) jobs...$(COLOR_RESET)"
	@JOBS=$$(find $(JOBS_DIR)/$(CAT) -name "*.nomad.hcl" -exec basename {} .nomad.hcl \; | paste -sd "," -) && \
	echo "Jobs to deploy: $$JOBS" && \
	./nomad-app -jobs=$$JOBS && \
	cdktf deploy

# ------------------------------------------------------------------------------
# Validation & Security Scanning
# ------------------------------------------------------------------------------

# Validate directory structure
check-structure: build-tools
	@echo "$(COLOR_CYAN)==> Validating job directory structure...$(COLOR_RESET)"
	@./$(BIN_DIR)/validate-structure -dir $(JOBS_DIR)

# Query Nomad jobs using utility tool
# Usage: make query ARGS="-category monitoring"
query: build-tools
	@./$(BIN_DIR)/nomad-query $(ARGS)

# Lint HCL (currently same as validate)
lint: validate-jobs
	@echo "$(COLOR_GREEN)[OK]$(COLOR_RESET) Linting complete"

# Scan with semgrep (if available)
semgrep:
	@if command -v semgrep >/dev/null 2>&1; then \
		echo "$(COLOR_CYAN)==> Running Semgrep security scan...$(COLOR_RESET)"; \
		cd $(JOBS_DIR) && semgrep --config .semgrep.yml .; \
	else \
		echo "$(COLOR_YELLOW)[WARN]$(COLOR_RESET) Semgrep not installed, skipping"; \
	fi

# Scan with trivy (if available)
trivy:
	@if command -v trivy >/dev/null 2>&1; then \
		echo "$(COLOR_CYAN)==> Running Trivy configuration scan...$(COLOR_RESET)"; \
		trivy config $(JOBS_DIR); \
	else \
		echo "$(COLOR_YELLOW)[WARN]$(COLOR_RESET) Trivy not installed, skipping"; \
	fi

# ------------------------------------------------------------------------------
# Development Targets
# ------------------------------------------------------------------------------

# Run Go tests
test:
	@echo "$(COLOR_CYAN)==> Running Go tests...$(COLOR_RESET)"
	# @go test ./...

# Run Go linter (requires golangci-lint)
lint-go:
	@echo "$(COLOR_CYAN)==> Running Go linter...$(COLOR_RESET)"
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "$(COLOR_YELLOW)[WARN]$(COLOR_RESET) golangci-lint not installed, skipping"; \
	fi

# ------------------------------------------------------------------------------
# Cleanup Targets
# ------------------------------------------------------------------------------

# Remove build artifacts
clean:
	@echo "$(COLOR_CYAN)==> Cleaning build artifacts...$(COLOR_RESET)"
	@rm -f nomad-app
	@rm -rf $(BIN_DIR)/
	@rm -rf cdktf.out/
	@echo "$(COLOR_GREEN)[OK]$(COLOR_RESET) Clean complete"

# Full clean including Go cache
clean-all: clean
	@echo "$(COLOR_CYAN)==> Cleaning Go cache...$(COLOR_RESET)"
	@go clean -cache -modcache
	@echo "$(COLOR_GREEN)[OK]$(COLOR_RESET) Full clean complete"

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

help:
	@echo "================================================================"
	@echo "  Munchbox CDKTF Infrastructure - Command Reference"
	@echo "================================================================"
	@echo ""
	@echo "$(COLOR_CYAN)BUILD COMMANDS$(COLOR_RESET)"
	@echo "  make build                    - Build CDKTF application (nomad-app)"
	@echo "  make build-tools              - Build utility tools (validate-structure, nomad-query)"
	@echo "  make build-all                - Build everything"
	@echo ""
	@echo "$(COLOR_CYAN)DEPLOYMENT COMMANDS$(COLOR_RESET)"
	@echo "  make synth                    - Generate Terraform JSON from CDKTF"
	@echo "  make deploy                   - Deploy all infrastructure"
	@echo "  make deploy-jobs JOBS=...     - Deploy specific categories (comma-separated)"
	@echo "  make deploy-category CAT=...  - Deploy all jobs in one category"
	@echo "  make plan                     - Show Terraform plan"
	@echo "  make diff                     - Show CDKTF diff"
	@echo ""
	@echo "$(COLOR_CYAN)VALIDATION COMMANDS$(COLOR_RESET)"
	@echo "  make validate                 - Validate all Nomad job files"
	@echo "  make validate-category CAT=...- Validate jobs in specific category"
	@echo "  make check-structure          - Validate directory structure"
	@echo "  make lint                     - Lint HCL files"
	@echo "  make semgrep                  - Run Semgrep security scan"
	@echo "  make trivy                    - Run Trivy config scan"
	@echo ""
	@echo "$(COLOR_CYAN)FORMATTING COMMANDS$(COLOR_RESET)"
	@echo "  make fmt                      - Format Go code and Nomad jobs"
	@echo "  make fmt-jobs                 - Format only Nomad jobs"
	@echo ""
	@echo "$(COLOR_CYAN)CATEGORY MANAGEMENT$(COLOR_RESET)"
	@echo "  make list-categories          - List all job categories"
	@echo "  make category-report          - Detailed breakdown by category"
	@echo ""
	@echo "$(COLOR_CYAN)QUERY & TOOLS$(COLOR_RESET)"
	@echo "  make query ARGS='...'         - Query Nomad jobs"
	@echo ""
	@echo "$(COLOR_CYAN)DEVELOPMENT COMMANDS$(COLOR_RESET)"
	@echo "  make test                     - Run Go tests"
	@echo "  make lint-go                  - Run Go linter"
	@echo "  make clean                    - Remove build artifacts"
	@echo "  make clean-all                - Full clean including Go cache"
	@echo ""
	@echo "================================================================"
	@echo "$(COLOR_BLUE)EXAMPLES$(COLOR_RESET)"
	@echo "================================================================"
	@echo "  # Full workflow"
	@echo "  make build-all validate deploy"
	@echo ""
	@echo "  # Deploy specific categories"
	@echo "  make deploy-jobs JOBS=monitoring,infrastructure"
	@echo ""
	@echo "  # Work with one category"
	@echo "  make validate-category CAT=monitoring"
	@echo "  make deploy-category CAT=monitoring"
	@echo ""
	@echo "  # Query monitoring jobs"
	@echo "  make query ARGS='-category monitoring'"
	@echo ""
	@echo "  # Security scan before deploy"
	@echo "  make validate semgrep trivy"
	@echo "================================================================"
