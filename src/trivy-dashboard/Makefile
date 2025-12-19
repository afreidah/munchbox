# -------------------------------------------------------------------------------
# Trivy Dashboard - Multi-Architecture Build and Push
#
# Project: Munchbox / Author: Alex Freidah
#
# Go web application for viewing Trivy CVE scan results. Builds multi-arch
# container images for deployment on heterogeneous Nomad clients.
# -------------------------------------------------------------------------------

REGISTRY   ?= registry.munchbox.cc
IMAGE      := trivy-dashboard
VERSION    ?= latest

FULL_TAG   := $(REGISTRY)/$(IMAGE):$(VERSION)
PLATFORMS  := linux/amd64,linux/arm64

# -------------------------------------------------------------------------
# DEFAULT TARGET
# -------------------------------------------------------------------------

help: ## Display available Make targets
	@echo ""
	@echo "Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' Makefile | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  %-15s %s\n", $$1, $$2}'
	@echo ""

# -------------------------------------------------------------------------
# BUILDX SETUP
# -------------------------------------------------------------------------

builder: ## Ensure the Buildx builder exists
	@docker buildx inspect munchbox-builder >/dev/null 2>&1 || \
		docker buildx create --name munchbox-builder --use
	@docker buildx inspect --bootstrap

# -------------------------------------------------------------------------
# BUILD (LOCAL)
# -------------------------------------------------------------------------

build: ## Build for local architecture
	@echo "Building $(FULL_TAG) for local architecture"
	docker build -t $(FULL_TAG) .

# -------------------------------------------------------------------------
# BUILD AND PUSH (MULTI-ARCH)
# -------------------------------------------------------------------------

push: builder ## Build and push multi-arch images to registry
	@echo "Building and pushing $(FULL_TAG) for $(PLATFORMS)"
	docker buildx build \
	  --platform $(PLATFORMS) \
	  -t $(FULL_TAG) \
	  --push \
	  .

# -------------------------------------------------------------------------
# DEVELOPMENT
# -------------------------------------------------------------------------

test: ## Run Go tests
	go test -v ./...

lint: ## Run Go linter
	@command -v golangci-lint >/dev/null 2>&1 || { echo "golangci-lint not installed"; exit 1; }
	golangci-lint run ./...

run: build ## Run locally on port 8080
	docker run --rm -p 8080:8080 $(FULL_TAG)

# -------------------------------------------------------------------------
# CLEANUP
# -------------------------------------------------------------------------

clean: ## Remove build artifacts and local image
	go clean
	docker rmi $(FULL_TAG) || true

.PHONY: help builder build push test lint run clean
.DEFAULT_GOAL := help
