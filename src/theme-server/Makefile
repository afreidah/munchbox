# -------------------------------------------------------------------------------
# Theme Server - Multi-Architecture Build and Push
#
# Project: Munchbox / Author: Alex Freidah
#
# Multi-architecture container pipeline for the theme server. Builds and
# publishes amd64 and arm64 variants using Docker Buildx.
# -------------------------------------------------------------------------------

REGISTRY   ?= registry.service.consul:5000
IMAGE      := theme-server
VERSION    ?= latest

FULL_TAG   := $(REGISTRY)/$(IMAGE):$(VERSION)
CACHE_TAG  := $(REGISTRY)/$(IMAGE):cache
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

push: builder ## Build and push multi-arch images
	@echo "Building and pushing $(FULL_TAG) for $(PLATFORMS)"
	docker buildx build \
	  --platform $(PLATFORMS) \
	  -t $(FULL_TAG) \
	  --cache-from type=registry,ref=$(CACHE_TAG) \
	  --cache-to type=registry,ref=$(CACHE_TAG),mode=max \
	  --output type=image,push=true,registry.insecure=true \
	  .

# -------------------------------------------------------------------------
# LOCAL DEVELOPMENT
# -------------------------------------------------------------------------

run: build ## Run locally on port 8080
	@echo "Running $(FULL_TAG) on port 8080"
	docker run --rm -p 8080:80 $(FULL_TAG)

# -------------------------------------------------------------------------
# CLEANUP
# -------------------------------------------------------------------------

clean: ## Remove local image
	docker rmi $(FULL_TAG) || true

.PHONY: help builder build push run clean
