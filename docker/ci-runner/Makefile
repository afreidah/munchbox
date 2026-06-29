# -------------------------------------------------------------------------------
# ci-runner Image Build
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

REGISTRY := registry.munchbox.cc
IMAGE := ci-runner
TAG := latest

FULL_IMAGE := $(REGISTRY)/$(IMAGE)

.PHONY: help build build-multiarch push clean
.DEFAULT_GOAL := help

help: ## Show this help
	@echo "ci-runner Image Build"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: ## Build for the current architecture
	docker build -t $(FULL_IMAGE):$(TAG) .

build-multiarch: ## Build for the current platform into the local daemon
	docker buildx create --name munchbox-builder --driver-opt network=host --use 2>/dev/null || docker buildx use munchbox-builder
	docker buildx build -t $(FULL_IMAGE):$(TAG) --load .

push: ## Build and push multi-arch (amd64 + arm64) to the registry
	docker buildx create --name munchbox-builder --driver-opt network=host --use 2>/dev/null || docker buildx use munchbox-builder
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		-t $(FULL_IMAGE):$(TAG) \
		--push \
		.

clean: ## Remove the local image
	docker rmi $(FULL_IMAGE):$(TAG) 2>/dev/null || true
