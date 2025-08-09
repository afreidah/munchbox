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

# -------------------------------------------------------------------------------
# CDKTF/ Terraform/Cloud Security Testing Tasks (cdktf/*)
# -------------------------------------------------------------------------------

.PHONY: cdktf-synth

cdktf-synth:
	@echo "Running synth"

cdktf-trivy: cdktf-synth
	@for dir in $$(find cdktf -mindepth 1 -maxdepth 1 -type d); do \
		if [ -d "$$dir/cdktf.out" ]; then \
			echo "Running Trivy scan in $$dir/cdktf.out..."; \
			trivy config --scan terraform --exit-code 1 --severity HIGH,CRITICAL "$$dir/cdktf.out" || true; \
		fi \
	done

cdktf-checkov: cdktf-synth
	@for dir in $$(find cdktf -mindepth 1 -maxdepth 1 -type d); do \
		if [ -d "$$dir/cdktf.out" ]; then \
			echo "Running Checkov scan in $$dir/cdktf.out..."; \
			checkov -d "$$dir/cdktf.out" || true; \
		fi \
	done

cdktf-fmt:
	@for dir in $$(find cdktf -mindepth 1 -maxdepth 1 -type d); do \
		if ls "$$dir"/*.go >/dev/null 2>&1; then \
			echo "Running go fmt in $$dir..."; \
			cd "$$dir" && go fmt ./...; \
		fi \
	done
