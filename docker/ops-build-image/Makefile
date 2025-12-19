# -------------------------------------------------------------------------------
# Ops Build Image - Multi-Architecture Build and Push
#
# Project: Munchbox / Author: Alex Freidah
#
# CI/CD toolchain image with infrastructure tools. Builds multi-arch container
# images for deployment on heterogeneous Nomad clients.
# -------------------------------------------------------------------------------

REGISTRY   ?= registry.service.consul:5000
IMAGE      := ops-build-image
VERSION    ?= latest

FULL_TAG   := $(REGISTRY)/$(IMAGE):$(VERSION)
CACHE_TAG  := $(REGISTRY)/$(IMAGE):cache
PLATFORMS  := linux/amd64,linux/arm64

.PHONY: help builder build build-multiarch test push clean
.DEFAULT_GOAL := help

# -------------------------------------------------------------------------------
# Help
# -------------------------------------------------------------------------------

help: ## Display available Make targets
	@echo ""
	@echo "Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' Makefile | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""

# -------------------------------------------------------------------------------
# Buildx Setup
# -------------------------------------------------------------------------------

builder: ## Ensure the Buildx builder exists
	@docker buildx inspect munchbox-builder >/dev/null 2>&1 || \
		docker buildx create --name munchbox-builder --use
	@docker buildx inspect --bootstrap

# -------------------------------------------------------------------------------
# Build
# -------------------------------------------------------------------------------

build: ## Build for local architecture only
	@echo "Building $(FULL_TAG) for local architecture"
	docker build -t $(FULL_TAG) .

build-multiarch: builder ## Build multi-arch images locally (no push)
	@echo "Building $(FULL_TAG) for $(PLATFORMS)"
	docker buildx build \
		--platform $(PLATFORMS) \
		-t $(FULL_TAG) \
		--cache-from type=registry,ref=$(CACHE_TAG) \
		--cache-to type=registry,ref=$(CACHE_TAG),mode=max \
		.

# -------------------------------------------------------------------------------
# Test
# -------------------------------------------------------------------------------

test: ## Validate image by checking tool versions
	@echo "Testing $(FULL_TAG)"
	@docker run --rm $(FULL_TAG) sh -c ' \
		echo "=== Validating tools ===" && \
		nomad version && \
		nomad-pack version && \
		terraform version | head -n1 && \
		consul version | head -n1 && \
		vault version | head -n1 && \
		go version && \
		make --version | head -n1 && \
		git --version && \
		echo "=== All tools OK ==="'

# -------------------------------------------------------------------------------
# Push
# -------------------------------------------------------------------------------

push: builder ## Build and push multi-arch images to registry
	@echo "Building and pushing $(FULL_TAG) for $(PLATFORMS)"
	docker buildx build \
		--platform $(PLATFORMS) \
		-t $(FULL_TAG) \
		--cache-from type=registry,ref=$(CACHE_TAG) \
		--cache-to type=registry,ref=$(CACHE_TAG),mode=max \
		--output type=image,push=true,registry.insecure=true \
		.

# -------------------------------------------------------------------------------
# Cleanup
# -------------------------------------------------------------------------------

clean: ## Remove local image
	docker rmi $(FULL_TAG) || true
