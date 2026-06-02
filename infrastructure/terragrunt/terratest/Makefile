# -----------------------------------------------------------------------------
# Munchbox terratest -- real-apply integration tests against live cluster.
#
# Each subdir under terratest/ is a Go test package for one terragrunt
# module. Tests apply against the LIVE cluster using sandbox prefixes/
# folders/keys; they need a real consul/vault/grafana token, sourced from
# munchbox-env.sh.
#
# Targets:
#   tidy            go mod tidy (sync deps)
#   test            run every terratest package (parallel-safe)
#   prometheus-alerts  run just the prometheus-alerts package
#   clean           strip cache / test binaries
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

GO        := go
TEST_FLAGS := -v -timeout 10m -count=1

.DEFAULT_GOAL := help
.PHONY: help tidy test prometheus-alerts grafana-dashboards clean

help:  ## list targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort -u

tidy:  ## go mod tidy (sync deps + go.sum)
	$(GO) mod tidy

test:  ## run every terratest package
	$(GO) test $(TEST_FLAGS) ./...

prometheus-alerts:  ## run just the prometheus-alerts package
	$(GO) test $(TEST_FLAGS) ./prometheus_alerts/...

grafana-dashboards:  ## run just the grafana-dashboards package
	$(GO) test $(TEST_FLAGS) ./grafana_dashboards/...

clean:  ## strip test binaries + go build cache
	$(GO) clean -testcache
