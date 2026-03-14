# -------------------------------------------------------------------------------
# Cloudflare Log Collector - Build, Package, and Push
#
# Author: Alex Freidah
#
# Go-based Cloudflare analytics collector. Builds multi-arch container images
# for deployment to the munchbox Nomad cluster.
# -------------------------------------------------------------------------------

REGISTRY   ?= registry.munchbox.cc
IMAGE      := cloudflare-log-collector
VERSION    ?= $(shell cat .version)

FULL_TAG   := $(REGISTRY)/$(IMAGE):$(VERSION)
CACHE_TAG  := $(REGISTRY)/$(IMAGE):cache
PLATFORMS  := linux/amd64,linux/arm64

# --- Go build flags ---
GO_LDFLAGS := -s -w -X github.com/afreidah/cloudflare-log-collector/internal/telemetry.Version=$(VERSION)


# -------------------------------------------------------------------------
# DEFAULT TARGET
# -------------------------------------------------------------------------

help: ## Display available Make targets
	@echo ""
	@echo "Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' Makefile | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""

# -------------------------------------------------------------------------
# BUILDX SETUP
# -------------------------------------------------------------------------

builder: ## Ensure the Buildx builder exists
	@docker buildx inspect cflog-builder >/dev/null 2>&1 || \
		docker buildx create --name cflog-builder --driver-opt network=host --use
	@docker buildx inspect --bootstrap

# -------------------------------------------------------------------------
# BUILD
# -------------------------------------------------------------------------

build: ## Build the Go binary for the local platform
	go build -ldflags="$(GO_LDFLAGS)" -o cloudflare-log-collector ./cmd/cloudflare-log-collector

# -------------------------------------------------------------------------
# DOCKER
# -------------------------------------------------------------------------

docker: ## Build Docker image for local architecture
	@echo "Building $(FULL_TAG) for local architecture"
	docker build --pull --build-arg VERSION=$(VERSION) -t $(FULL_TAG) .

# -------------------------------------------------------------------------
# BUILD AND PUSH (MULTI-ARCH)
# -------------------------------------------------------------------------

push: builder ## Build and push multi-arch images to registry
	@echo "Building and pushing $(FULL_TAG) for $(PLATFORMS)"
	docker buildx build \
	  --pull \
	  --platform $(PLATFORMS) \
	  --build-arg VERSION=$(VERSION) \
	  -t $(FULL_TAG) \
	  --cache-from type=registry,ref=$(CACHE_TAG) \
	  --cache-to type=registry,ref=$(CACHE_TAG),mode=max \
	  --output type=image,push=true \
	  .

# -------------------------------------------------------------------------
# DEVELOPMENT
# -------------------------------------------------------------------------

test: ## Run Go tests with coverage
	go test -race -cover ./...

vet: ## Run Go vet static analysis
	go vet ./...

lint: ## Run Go linter
	go run github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.10.1 run ./...

run: ## Run locally (requires config.yaml)
	go run ./cmd/cloudflare-log-collector -config config.yaml

# -------------------------------------------------------------------------
# CLEANUP
# -------------------------------------------------------------------------

clean: ## Remove build artifacts
	go clean
	rm -f cloudflare-log-collector
	docker rmi $(FULL_TAG) 2>/dev/null || true

.PHONY: help builder build docker push test vet lint run clean
.DEFAULT_GOAL := help
