# -------------------------------------------------------------------------------
# Patroni Image Build
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

REGISTRY := registry.munchbox.cc
IMAGE := patroni
TAG := latest
PG_VERSION := 18
PATRONI_VERSION := 4.0.4

FULL_IMAGE := $(REGISTRY)/$(IMAGE)

.PHONY: help build build-multiarch push clean
.DEFAULT_GOAL := help

help: ## Show this help
	@echo "Patroni Image Build"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: ## Build for current architecture
	docker build -t $(FULL_IMAGE):$(TAG) -t $(FULL_IMAGE):pg$(PG_VERSION) .

build-multiarch: ## Build multi-arch image (amd64 + arm64)
	docker buildx create --name munchbox-builder --use 2>/dev/null || docker buildx use munchbox-builder
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		-t $(FULL_IMAGE):$(TAG) \
		-t $(FULL_IMAGE):pg$(PG_VERSION) \
		-t $(FULL_IMAGE):pg$(PG_VERSION)-patroni$(PATRONI_VERSION) \
		--load \
		.

push: ## Build and push to registry
	docker buildx create --name munchbox-builder --use 2>/dev/null || docker buildx use munchbox-builder
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		-t $(FULL_IMAGE):$(TAG) \
		-t $(FULL_IMAGE):pg$(PG_VERSION) \
		-t $(FULL_IMAGE):pg$(PG_VERSION)-patroni$(PATRONI_VERSION) \
		--push \
		.

clean: ## Remove local images
	docker rmi $(FULL_IMAGE):$(TAG) $(FULL_IMAGE):pg$(PG_VERSION) 2>/dev/null || true
