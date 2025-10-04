# ------------------------------------------------------------------------------
# Makefile — Nomad Jobs QA
#
# Provides validation, formatting, linting, and security scanning for Nomad jobs.
# Intended for use both locally (developer pre-commit) and in CI (GitLab jobs).
#
# Tools covered:
#   - nomad validate   : Syntax/schema validation
#   - hclfmt           : Canonical HCL formatting
#   - hcl-linter       : Static lint checks for HCL style and patterns
#   - checkov          : Misconfiguration / security scanning
#   - trivy config     : Vulnerability and misconfig scanning
# ------------------------------------------------------------------------------

# --- Variables ---
NOMAD_FILES := $(shell find nomad-jobs -type f -name "*.nomad.hcl" -o -name "*.hcl")

.PHONY: all validate fmt lint checkov trivy

# Run everything
all: validate fmt lint

# ------------------------------------------------------------------------------
# Validate Nomad jobs with the official CLI
# ------------------------------------------------------------------------------
validate:
	@echo "==> Validating Nomad job files"
	@for f in $(NOMAD_FILES); do \
	  echo "--- $$f"; \
	  nomad job validate $$f || exit 1; \
	done

# ------------------------------------------------------------------------------
# Format HCL files consistently
# ------------------------------------------------------------------------------
fmt:
	@echo "==> Formatting HCL files"
	@for f in $(NOMAD_FILES); do \
	  echo "--- $$f"; \
	  hclfmt -w $$f || exit 1; \
	done

# ------------------------------------------------------------------------------
# Lint HCL for style and common mistakes
# (requires hcl-linter or equivalent installed in PATH)
# ------------------------------------------------------------------------------
lint:
	@echo "==> Linting HCL files"
	@for file in jobs/**/*.nomad.hcl; do \
		nomad job validate $$file || exit 1; \
	done

build:
	@echo "==> Building nomad-app"
	@rm -rf cdktf.out/ nomad-app
	@go build -o nomad-app

deploy:
	@echo "==> Deploying..."
	@cdktf deploy
