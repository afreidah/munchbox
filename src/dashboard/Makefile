# -------------------------------------------------------------------------------
# Munchbox Dashboard - Multi-Architecture Build and Push
#
# Project: Munchbox / Author: Alex Freidah
#
# Multi-architecture container pipeline for the Munchbox dashboard. Builds and
# publishes amd64 and arm64 variants using Docker Buildx with a unified manifest
# to ensure consistent scheduling behavior across heterogeneous Nomad clients.
# -------------------------------------------------------------------------------

REGISTRY   ?= registry.munchbox.cc
IMAGE      := dash
VERSION    ?= latest

FULL_TAG   := $(REGISTRY)/$(IMAGE):$(VERSION)
CACHE_TAG  := $(REGISTRY)/$(IMAGE):cache
PLATFORMS  := linux/amd64,linux/arm64

# -------------------------------------------------------------------------
# DEFAULT TARGET
# -------------------------------------------------------------------------

## Display available Make targets and descriptions
help:
	@echo ""
	@echo "Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' Makefile | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  %-15s %s\n", $$1, $$2}'
	@echo ""

# -------------------------------------------------------------------------
# BUILDX SETUP
# -------------------------------------------------------------------------

builder: ## Ensure the Buildx builder exists and is ready
	@echo "Ensuring Buildx builder exists"
	docker buildx inspect munchbox-builder >/dev/null 2>&1 || \
		docker buildx create --name munchbox-builder --driver-opt network=host --use
	docker buildx inspect --bootstrap

# -------------------------------------------------------------------------
# BUILD (LOCAL, SINGLE ARCH)
# -------------------------------------------------------------------------

build: ## Build the dashboard image for the local architecture
	@echo "Rebuilding Tailwind CSS"
	npm run build
	@echo "Building $(FULL_TAG) for local architecture"
	docker build -t $(FULL_TAG) .

# -------------------------------------------------------------------------
# BUILD AND PUSH (MULTI-ARCH)
# -------------------------------------------------------------------------

push: builder ## Build and push amd64 and arm64 images to the registry
	@echo "Rebuilding Tailwind CSS"
	npm run build
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

run: ## Run the dashboard container on port 8080
	@echo "Running $(FULL_TAG) on port 8080"
	docker run --rm -p 8080:80 $(FULL_TAG)

# -------------------------------------------------------------------------
# CLEANUP
# -------------------------------------------------------------------------

clean: ## Remove the local dashboard image
	@echo "Removing local image $(FULL_TAG)"
	docker rmi $(FULL_TAG) || true

.PHONY: help builder build push run clean
.DEFAULT_GOAL := help
