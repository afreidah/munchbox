# Munchbox Nomad Job Management
# -------------------------------------------------------------------------------

.PHONY: help list render plan run stop purge render-all plan-all run-all

PACK_REGISTRY := packs/registry
DEFAULT_PACK := nomad-service

# Help target
help:
	@echo "Nomad Job Management Commands:"
	@echo "  make list                    - List all available jobs"
	@echo "  make render JOB=<name>       - Render a specific job"
	@echo "  make plan JOB=<name>         - Plan a specific job"
	@echo "  make run JOB=<name>          - Run a specific job"
	@echo "  make stop JOB=<name>         - Stop a specific job"
	@echo "  make purge JOB=<name>        - Purge a specific job"
	@echo ""
	@echo "  make render-all              - Render all jobs"
	@echo "  make plan-all                - Plan all jobs"
	@echo "  make run-all                 - Run all jobs"
	@echo ""
	@echo "Examples:"
	@echo "  make render JOB=grafana"
	@echo "  make run JOB=temporal-backup-worker"

# Auto-discover all job files
JOBS := $(shell find jobs -name '*.hcl' -type f)

# List all jobs
list:
	@echo "Available jobs:"
	@for job in $(JOBS); do \
		echo "  - $$(basename $$job .hcl) ($$job)"; \
	done

# Helper function to find job file
define find-job
$(shell find jobs -name "$(1).hcl" -type f | head -1)
endef

# Helper function to get pack for job
define get-pack
$(shell if [ -f "$(1)" ]; then \
	grep -q "^# PACK:" "$(1)" && grep "^# PACK:" "$(1)" | awk '{print $$3}' || echo "$(DEFAULT_PACK)"; \
else \
	echo "$(DEFAULT_PACK)"; \
fi)
endef

# Helper function to get command type
define get-command-type
$(shell if [ -f "$(1)" ]; then \
	grep -q "^# TYPE: nomad" "$(1)" && echo "nomad" || echo "nomad-pack"; \
else \
	echo "nomad-pack"; \
fi)
endef

# Render a specific job
render:
ifndef JOB
	@echo "Error: JOB not specified. Usage: make render JOB=<job-name>"
	@exit 1
endif
	$(eval JOB_FILE := $(call find-job,$(JOB)))
	$(eval PACK := $(call get-pack,$(JOB_FILE)))
	$(eval CMD_TYPE := $(call get-command-type,$(JOB_FILE)))
	@if [ -z "$(JOB_FILE)" ]; then \
		echo "Error: Job '$(JOB)' not found"; \
		exit 1; \
	fi
	@echo "Rendering $(JOB) from $(JOB_FILE) using $(CMD_TYPE)..."
	@if [ "$(CMD_TYPE)" = "nomad" ]; then \
		nomad job run -check-index 0 -detach -verbose $(JOB_FILE); \
	else \
		nomad-pack render --var-file=$(JOB_FILE) $(PACK_REGISTRY)/$(PACK); \
	fi

# Plan a specific job
plan:
ifndef JOB
	@echo "Error: JOB not specified. Usage: make plan JOB=<job-name>"
	@exit 1
endif
	$(eval JOB_FILE := $(call find-job,$(JOB)))
	$(eval PACK := $(call get-pack,$(JOB_FILE)))
	$(eval CMD_TYPE := $(call get-command-type,$(JOB_FILE)))
	@if [ -z "$(JOB_FILE)" ]; then \
		echo "Error: Job '$(JOB)' not found"; \
		exit 1; \
	fi
	@echo "Planning $(JOB) from $(JOB_FILE) using $(CMD_TYPE)..."
	@if [ "$(CMD_TYPE)" = "nomad" ]; then \
		nomad job plan $(JOB_FILE); \
	else \
		nomad-pack plan --diff --var-file=$(JOB_FILE) $(PACK_REGISTRY)/$(PACK); \
	fi

# Run a specific job
run:
ifndef JOB
	@echo "Error: JOB not specified. Usage: make run JOB=<job-name>"
	@exit 1
endif
	$(eval JOB_FILE := $(call find-job,$(JOB)))
	$(eval PACK := $(call get-pack,$(JOB_FILE)))
	$(eval CMD_TYPE := $(call get-command-type,$(JOB_FILE)))
	@if [ -z "$(JOB_FILE)" ]; then \
		echo "Error: Job '$(JOB)' not found"; \
		exit 1; \
	fi
	@echo "Running $(JOB) from $(JOB_FILE) using $(CMD_TYPE)..."
	@if [ "$(CMD_TYPE)" = "nomad" ]; then \
		nomad job run $(JOB_FILE); \
	else \
		nomad-pack run --var-file=$(JOB_FILE) $(PACK_REGISTRY)/$(PACK); \
	fi

# Stop a specific job
stop:
ifndef JOB
	@echo "Error: JOB not specified. Usage: make stop JOB=<job-name>"
	@exit 1
endif
	@echo "Stopping $(JOB)..."
	@nomad job stop $(JOB)

# Purge a specific job
purge:
ifndef JOB
	@echo "Error: JOB not specified. Usage: make purge JOB=<job-name>"
	@exit 1
endif
	@echo "Purging $(JOB)..."
	@nomad job stop -purge $(JOB)

# Render all jobs
render-all:
	@for job in $(JOBS); do \
		job_name=$$(basename $$job .hcl); \
		echo "=== Rendering $$job_name ==="; \
		make render JOB=$$job_name || true; \
		echo ""; \
	done

# Plan all jobs
plan-all:
	@for job in $(JOBS); do \
		job_name=$$(basename $$job .hcl); \
		echo "=== Planning $$job_name ==="; \
		make plan JOB=$$job_name || true; \
		echo ""; \
	done

# Run all jobs (use with caution!)
run-all:
	@echo "WARNING: This will deploy ALL jobs. Press Ctrl+C to cancel or Enter to continue..."
	@read confirm
	@for job in $(JOBS); do \
		job_name=$$(basename $$job .hcl); \
		echo "=== Running $$job_name ==="; \
		make run JOB=$$job_name || true; \
		echo ""; \
	done
