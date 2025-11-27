# -------------------------------------------------------------------------------
# Munchbox Nomad Job Management
#
# Project: Munchbox / Author: Alex Freidah
#
# Unified interface for deploying Nomad jobs regardless of whether they use
# nomad-pack templates or raw HCL files.
#
# Usage:
#   make run JOB=grafana        # Deploy grafana job
#   make plan JOB=traefik       # Plan traefik changes
#   make render JOB=prometheus  # Render to see generated HCL
#   make list                   # Show all available jobs
# -------------------------------------------------------------------------------

.PHONY: help list render plan run stop purge validate

SHELL := /bin/bash

# Pack registry location (relative to this Makefile)
PACK_REGISTRY := packs

# Default pack for jobs without explicit PACK directive
DEFAULT_PACK := munchbox-service

# -------------------------------------------------------------------------------
# Help
# -------------------------------------------------------------------------------

help:
	@echo "Nomad Job Management"
	@echo ""
	@echo "Commands:"
	@echo "  make list                 List all available jobs"
	@echo "  make render JOB=<name>    Render job template (show generated HCL)"
	@echo "  make plan JOB=<name>      Plan job deployment (diff)"
	@echo "  make run JOB=<name>       Deploy job"
	@echo "  make stop JOB=<name>      Stop running job"
	@echo "  make purge JOB=<name>     Stop and purge job"
	@echo "  make validate JOB=<name>  Validate job syntax"
	@echo ""
	@echo "Examples:"
	@echo "  make run JOB=grafana"
	@echo "  make plan JOB=traefik"
	@echo "  make render JOB=prometheus"
	@echo ""
	@echo "Job Detection:"
	@echo "  - Files ending in .nomad.hcl -> nomad job run (raw HCL)"
	@echo "  - Files with '# PACK: <name>' -> uses that pack"
	@echo "  - All other .hcl files -> uses $(DEFAULT_PACK) pack"

# -------------------------------------------------------------------------------
# Job Discovery
# -------------------------------------------------------------------------------

# Find all job files (both pack var files and raw nomad files)
JOBS := $(shell find jobs -name '*.hcl' -type f 2>/dev/null | sort)

list:
	@echo "Available Jobs:"
	@echo ""
	@for job in $(JOBS); do \
		name=$$(basename "$$job" .hcl); \
		name=$${name%.nomad}; \
		dir=$$(dirname "$$job" | sed 's|jobs/||'); \
		if echo "$$job" | grep -q '\.nomad\.hcl$$'; then \
			type="[raw]"; \
		elif grep -q '^# PACK:' "$$job" 2>/dev/null; then \
			pack=$$(grep '^# PACK:' "$$job" | awk '{print $$3}'); \
			type="[pack:$$pack]"; \
		else \
			type="[pack:$(DEFAULT_PACK)]"; \
		fi; \
		printf "  %-25s %-20s %s\n" "$$name" "$$type" "$$dir"; \
	done
	@echo ""

# -------------------------------------------------------------------------------
# Internal: Find job file and determine how to run it
# -------------------------------------------------------------------------------

# --- Find job file by name (searches recursively) ---
define find_job
$(shell find jobs -name "$(1).hcl" -o -name "$(1).nomad.hcl" 2>/dev/null | head -1)
endef

# --- Get job directory (for passing to pack) ---
define get_job_dir
$(shell dirname "$(1)")
endef

# --- Determine if job is raw HCL (ends in .nomad.hcl) ---
define is_raw_hcl
$(shell echo "$(1)" | grep -q '\.nomad\.hcl$$' && echo "yes" || echo "no")
endef

# --- Get pack name from job file (or default) ---
define get_pack
$(shell if grep -q '^# PACK:' "$(1)" 2>/dev/null; then \
	grep '^# PACK:' "$(1)" | awk '{print $$3}'; \
else \
	echo "$(DEFAULT_PACK)"; \
fi)
endef

# -------------------------------------------------------------------------------
# Commands
# -------------------------------------------------------------------------------

render:
ifndef JOB
	$(error JOB not specified. Usage: make render JOB=<name>)
endif
	$(eval JOB_FILE := $(call find_job,$(JOB)))
	@if [ -z "$(JOB_FILE)" ]; then \
		echo "Error: Job '$(JOB)' not found"; \
		echo "Run 'make list' to see available jobs"; \
		exit 1; \
	fi
	$(eval JOB_DIR := $(call get_job_dir,$(JOB_FILE)))
	$(eval IS_RAW := $(call is_raw_hcl,$(JOB_FILE)))
	$(eval PACK := $(call get_pack,$(JOB_FILE)))
	@echo "=== Rendering $(JOB) ==="
	@echo "File: $(JOB_FILE)"
	@if [ "$(IS_RAW)" = "yes" ]; then \
		echo "Type: Raw HCL"; \
		echo ""; \
		cat "$(JOB_FILE)"; \
	else \
		echo "Type: Pack ($(PACK))"; \
		echo ""; \
		nomad-pack render \
			--var-file="$(JOB_FILE)" \
			--var="job_dir=$(shell pwd)/$(JOB_DIR)" \
			"$(PACK_REGISTRY)/$(PACK)"; \
	fi

plan:
ifndef JOB
	$(error JOB not specified. Usage: make plan JOB=<name>)
endif
	$(eval JOB_FILE := $(call find_job,$(JOB)))
	@if [ -z "$(JOB_FILE)" ]; then \
		echo "Error: Job '$(JOB)' not found"; \
		exit 1; \
	fi
	$(eval JOB_DIR := $(call get_job_dir,$(JOB_FILE)))
	$(eval IS_RAW := $(call is_raw_hcl,$(JOB_FILE)))
	$(eval PACK := $(call get_pack,$(JOB_FILE)))
	@echo "=== Planning $(JOB) ==="
	@if [ "$(IS_RAW)" = "yes" ]; then \
		nomad job plan "$(JOB_FILE)"; \
	else \
		nomad-pack plan \
			--var-file="$(JOB_FILE)" \
			--var="job_dir=$(shell pwd)/$(JOB_DIR)" \
			"$(PACK_REGISTRY)/$(PACK)"; \
	fi

run:
ifndef JOB
	$(error JOB not specified. Usage: make run JOB=<name>)
endif
	$(eval JOB_FILE := $(call find_job,$(JOB)))
	@if [ -z "$(JOB_FILE)" ]; then \
		echo "Error: Job '$(JOB)' not found"; \
		exit 1; \
	fi
	$(eval JOB_DIR := $(call get_job_dir,$(JOB_FILE)))
	$(eval IS_RAW := $(call is_raw_hcl,$(JOB_FILE)))
	$(eval PACK := $(call get_pack,$(JOB_FILE)))
	@echo "=== Deploying $(JOB) ==="
	@if [ "$(IS_RAW)" = "yes" ]; then \
		nomad job run "$(JOB_FILE)"; \
	else \
		nomad-pack run \
			--var-file="$(JOB_FILE)" \
			--var="job_dir=$(shell pwd)/$(JOB_DIR)" \
			"$(PACK_REGISTRY)/$(PACK)"; \
	fi

validate:
ifndef JOB
	$(error JOB not specified. Usage: make validate JOB=<name>)
endif
	$(eval JOB_FILE := $(call find_job,$(JOB)))
	@if [ -z "$(JOB_FILE)" ]; then \
		echo "Error: Job '$(JOB)' not found"; \
		exit 1; \
	fi
	$(eval JOB_DIR := $(call get_job_dir,$(JOB_FILE)))
	$(eval IS_RAW := $(call is_raw_hcl,$(JOB_FILE)))
	$(eval PACK := $(call get_pack,$(JOB_FILE)))
	@echo "=== Validating $(JOB) ==="
	@if [ "$(IS_RAW)" = "yes" ]; then \
		nomad job validate "$(JOB_FILE)"; \
	else \
		nomad-pack render \
			--var-file="$(JOB_FILE)" \
			--var="job_dir=$(shell pwd)/$(JOB_DIR)" \
			"$(PACK_REGISTRY)/$(PACK)" | nomad job validate -; \
	fi

stop:
ifndef JOB
	$(error JOB not specified. Usage: make stop JOB=<name>)
endif
	@echo "=== Stopping $(JOB) ==="
	@nomad job stop "$(JOB)" || true

purge:
ifndef JOB
	$(error JOB not specified. Usage: make purge JOB=<name>)
endif
	@echo "=== Purging $(JOB) ==="
	@nomad job stop -purge "$(JOB)" || true

# -------------------------------------------------------------------------------
# Batch Operations
# -------------------------------------------------------------------------------

.PHONY: render-all plan-all validate-all

render-all:
	@for job in $(JOBS); do \
		name=$$(basename "$$job" .hcl); \
		name=$${name%.nomad}; \
		echo ""; \
		$(MAKE) render JOB=$$name || true; \
	done

plan-all:
	@for job in $(JOBS); do \
		name=$$(basename "$$job" .hcl); \
		name=$${name%.nomad}; \
		echo ""; \
		$(MAKE) plan JOB=$$name || true; \
	done

validate-all:
	@for job in $(JOBS); do \
		name=$$(basename "$$job" .hcl); \
		name=$${name%.nomad}; \
		echo ""; \
		$(MAKE) validate JOB=$$name || true; \
	done
