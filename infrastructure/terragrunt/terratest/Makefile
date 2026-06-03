# -----------------------------------------------------------------------------
# Munchbox terratest -- real-apply integration tests against live cluster.
#
# Each subdir under terratest/ is a Go test package for one terragrunt
# module. Tests apply against the LIVE cluster using sandbox prefixes/
# folders/keys; they need a real consul/vault/grafana token, sourced from
# munchbox-env.sh.
#
# Run `make help` for the current target list.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

GO        := go
TEST_FLAGS := -v -timeout 10m -count=1

.DEFAULT_GOAL := help
.PHONY: help tidy test prometheus-alerts grafana-dashboards clean

help: ## Display available Make targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z0-9_-]+:.*?## / { \
			gsub(/[A-Z_][A-Z0-9_]*=[a-zA-Z0-9_|-]+/, "\033[33m&\033[0m", $$2); \
			printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 \
		} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)}' $(MAKEFILE_LIST)

##@ Setup

tidy: ## go mod tidy (sync deps + go.sum)
	$(GO) mod tidy

##@ Test

test: ## Run every terratest package
	$(GO) test $(TEST_FLAGS) ./...

prometheus-alerts: ## Run just the prometheus-alerts package
	$(GO) test $(TEST_FLAGS) ./prometheus_alerts/...

grafana-dashboards: ## Run just the grafana-dashboards package
	$(GO) test $(TEST_FLAGS) ./grafana_dashboards/...

##@ Maintenance

clean: ## Strip test binaries + go build cache
	$(GO) clean -testcache
