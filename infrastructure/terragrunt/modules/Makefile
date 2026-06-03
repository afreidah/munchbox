# -----------------------------------------------------------------------------
# Munchbox Terraform Modules - Fleet Walker
#
# Runs any per-module target across every module that has its own Makefile.
# Per-module logic lives in _common.mk (each module's Makefile is a one-liner
# `include ../_common.mk`).
#
# Run `make help` for the current target list. Pass MODULE=<name> to scope
# any fleet target to a single module.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# --- pihole-dns declares configuration_aliases (pihole.primary, pihole.secondary) ---
# so it can't be validated standalone -- only via its consuming leaf. Skip it.
SKIP_MODULES := pihole-dns
MODULES := $(shell find . -mindepth 2 -maxdepth 2 -name Makefile -printf '%h\n' | sed 's|^\./||' | sort | grep -vxF -e $(SKIP_MODULES))
TARGETS := fmt fmt-fix validate lint trivy checkov test verify clean

.DEFAULT_GOAL := help
.PHONY: help list $(TARGETS)

help: ## Display available Make targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<target>\033[0m [MODULE=<name>]\n"} \
		/^[a-zA-Z0-9_-]+:.*?## / { \
			gsub(/[A-Z_][A-Z0-9_]*=[a-zA-Z0-9_|-]+/, "\033[33m&\033[0m", $$2); \
			printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 \
		} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)}' $(MAKEFILE_LIST)

##@ Fleet (runs in every module; pass MODULE=<name> for one)

fmt: ## terraform fmt -check across all modules
fmt-fix: ## terraform fmt (rewrites) across all modules
validate: ## terraform validate across all modules
lint: ## tflint across all modules
trivy: ## trivy config (IaC misconfig scan) across all modules
checkov: ## checkov (policy/compliance) across all modules
test: ## terraform test (plan-only suite) across all modules
verify: ## fmt + validate + lint + test across all modules
clean: ## remove .terraform/ + lockfile from all modules

##@ Meta

list: ## list discovered modules + fleet targets
	@echo "modules:"; for m in $(MODULES); do echo "  - $$m"; done; echo; \
	echo "targets: $(TARGETS)"

$(TARGETS):
	@if [ -n "$(MODULE)" ]; then \
	  $(MAKE) --no-print-directory -C "$(MODULE)" $@; \
	else \
	  pass=0; fail=0; failed=""; \
	  for m in $(MODULES); do \
	    printf "\n==> %s :: %s\n" "$$m" "$@"; \
	    if $(MAKE) --no-print-directory -C "$$m" $@; then \
	      pass=$$((pass+1)); \
	    else \
	      fail=$$((fail+1)); failed="$$failed $$m"; \
	    fi; \
	  done; \
	  echo; echo "==================================================="; \
	  echo "$@: passed $$pass, failed $$fail"; \
	  if [ "$$fail" -gt 0 ]; then echo "failed modules:$$failed"; fi; \
	  test "$$fail" -eq 0; \
	fi
