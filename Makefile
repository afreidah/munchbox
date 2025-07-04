# -------------------------------------------------------------------------------
# Makefile (repo root) — Nomad job validation, linting, and scanning (namespaced)
# -------------------------------------------------------------------------------

NOMAD_JOBS := $(wildcard nomad-jobs/*.nomad.hcl) $(wildcard nomad-jobs/batch-jobs/*.hcl)
NOMAD      ?= nomad

.PHONY: nomad-all nomad-validate nomad-semgrep nomad-checkov

nomad-all: nomad-validate nomad-semgrep nomad-checkov nomad-trivy

# -------------------------------------------------------------------------------
# Validate all Nomad job files using Nomad CLI
# -------------------------------------------------------------------------------
nomad-validate:
	@echo "Validating Nomad jobs..."
	@for file in $(NOMAD_JOBS); do \
		echo "Validating $$file"; \
		$(NOMAD) job validate "$$file" || exit 1; \
	done

# -------------------------------------------------------------------------------
#  Run Semgrep on Nomad job files for security and best practices
# -------------------------------------------------------------------------------
nomad-semgrep:
	@echo "Running Semgrep on Nomad jobs..."
	@which semgrep >/dev/null 2>&1 || (echo "semgrep not found. Install with 'pip install semgrep'" && exit 1)
	@semgrep --config nomad-jobs/.semgrep.yml $(NOMAD_JOBS)

# -------------------------------------------------------------------------------
# Scan HCL files for security issues using Checkov (https://www.checkov.io/)
# -------------------------------------------------------------------------------
nomad-checkov:
	@echo "Running Checkov scan..."
	@which checkov >/dev/null 2>&1 || (echo "checkov not found. Install with 'pip install checkov'" && exit 1)
	@checkov -d nomad-jobs

# -------------------------------------------------------------------------------
# nomad-test: Start Nomad dev agent, run/validate/purge all jobs, then shutdown
#
# - Starts a Nomad dev agent in the background
# - Validates, runs, checks, and purges each job file in nomad-jobs/
# - Strips out constraint blocks for local/dev testing so jobs can be placed
# - Skips server jobs (not supported in dev mode)
# - Handles batch jobs by checking for completion
# - Cleans up by killing the Nomad dev agent at the end
# -------------------------------------------------------------------------------
.PHONY: nomad-test

nomad-test:
	bash scripts/nomad-test.sh
