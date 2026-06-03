# -----------------------------------------------------------------------------
# Shared per-module Makefile targets for Munchbox terraform modules.
#
# Each module's Makefile is a one-liner: `include ../_common.mk`.
# Run any of these from inside a module dir, or from infrastructure/terragrunt
# /modules/ to walk every module.
#
# Run `make help` for the current target list.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

.DEFAULT_GOAL := help
.PHONY: help fmt fmt-fix validate lint trivy checkov test verify clean init init-tflint

help: ## Display available Make targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z0-9_-]+:.*?## / { \
			gsub(/[A-Z_][A-Z0-9_]*=[a-zA-Z0-9_|-]+/, "\033[33m&\033[0m", $$2); \
			printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 \
		} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)}' $(MAKEFILE_LIST)

init:
	@terraform init -backend=false -upgrade=false -no-color >/dev/null

init-tflint:
	@tflint --init --no-color >/dev/null 2>&1 || true

##@ Format

fmt: ## terraform fmt -check (read-only)
	@terraform fmt -check -recursive

fmt-fix: ## terraform fmt (rewrites)
	@terraform fmt -recursive

##@ Validate / Lint

validate: init ## terraform validate (runs init -backend=false first)
	@terraform validate -no-color

lint: init-tflint ## tflint (terraform-specific linter)
	@tflint --no-color --disable-rule=terraform_required_providers

##@ Scan

trivy: ## trivy config (IaC misconfig scan; bundles tfsec/tflint checks)
	@trivy config --quiet --exit-code 1 .

checkov: ## checkov (policy/compliance scan; skip list in modules/.checkov.yaml)
	@checkov --quiet --compact --directory . --framework terraform --config-file ../.checkov.yaml

##@ Test

test: init ## terraform test (plan-only suite from tests/)
	@terraform test -no-color

verify: fmt validate lint test ## fmt + validate + lint + test (trivy/checkov are ad-hoc)

##@ Maintenance

clean: ## remove .terraform/ + lockfile
	@rm -rf .terraform .terraform.lock.hcl
