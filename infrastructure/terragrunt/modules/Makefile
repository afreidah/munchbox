# -----------------------------------------------------------------------------
# Munchbox Terraform Modules - Fleet Walker
#
# Runs any per-module target across every module that has its own Makefile.
# Per-module logic lives in _common.mk (each module's Makefile is a one-liner
# `include ../_common.mk`).
#
# Usage:
#   make verify                  # fmt + validate + lint + trivy + checkov + test (every module)
#   make test                    # terraform test in every module
#   make lint MODULE=kms-oci     # one module, one target
#   make fmt-fix                 # rewrite via terraform fmt across all modules
#   make clean                   # nuke .terraform/ caches everywhere
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

MODULES := $(shell find . -mindepth 2 -maxdepth 2 -name Makefile -printf '%h\n' | sed 's|^\./||' | sort)
TARGETS := fmt fmt-fix validate lint trivy checkov test verify clean

.DEFAULT_GOAL := help
.PHONY: help list $(TARGETS)

help: ## list available targets
	@echo "Fleet targets (run in every module; pass MODULE=<name> for one):"
	@for t in $(TARGETS); do printf "  %s\n" "$$t"; done
	@echo
	@echo "Meta:"
	@echo "  list      list discovered modules + targets"
	@echo "  help      this message"
	@echo
	@echo "Examples:"
	@echo "  make verify                    # everything, every module"
	@echo "  make test MODULE=kms-oci       # just that module"
	@echo "  make -C kms-oci help           # per-module help"

list:
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
