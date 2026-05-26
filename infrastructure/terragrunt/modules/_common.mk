# -----------------------------------------------------------------------------
# Shared per-module Makefile targets for Munchbox terraform modules.
#
# Each module's Makefile is a one-liner: `include ../_common.mk`.
# Run any of these from inside a module dir, or from infrastructure/terragrunt
# /modules/ to walk every module.
#
# Targets:
#   fmt        terraform fmt -check (read-only)
#   fmt-fix    terraform fmt (rewrites)
#   validate   terraform init -backend=false && terraform validate
#   lint       tflint
#   trivy      trivy config (IaC misconfig scan)
#   checkov    checkov (policy/compliance scan)
#   test       terraform test (plan-only test suite from tests/)
#   verify     all of the above (fmt, validate, lint, trivy, checkov, test)
#   clean      remove .terraform/ + lockfile
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

.DEFAULT_GOAL := help
.PHONY: help fmt fmt-fix validate lint trivy checkov test verify clean init init-tflint

help: ## list available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort -u

init:
	@terraform init -backend=false -upgrade=false -no-color >/dev/null

init-tflint:
	@tflint --init --no-color >/dev/null 2>&1 || true

fmt: ## terraform fmt -check (read-only)
	@terraform fmt -check -recursive

fmt-fix: ## terraform fmt (rewrites)
	@terraform fmt -recursive

validate: init ## terraform validate (runs init -backend=false first)
	@terraform validate -no-color

lint: init-tflint ## tflint (terraform-specific linter)
	@tflint --no-color --disable-rule=terraform_required_providers

trivy: ## trivy config (IaC misconfig scan; bundles tfsec/tflint checks)
	@trivy config --quiet --exit-code 1 .

checkov: ## checkov (policy / compliance scan)
	@checkov --quiet --compact --directory . --framework terraform

test: init ## terraform test (plan-only suite from tests/)
	@terraform test -no-color

verify: fmt validate lint trivy checkov test ## fmt + validate + lint + trivy + checkov + test

clean: ## remove .terraform/ + lockfile
	@rm -rf .terraform .terraform.lock.hcl
