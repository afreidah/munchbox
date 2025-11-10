# filepath: docker/Makefile
# ═══════════════════════════════════════════════════════════════════════════
# Project: Munchbox
# Purpose: Build and push Docker images via Waypoint to private registry
# ═══════════════════════════════════════════════════════════════════════════
# Usage:
#   make help            # Show all targets
#   make build           # Build all images via Waypoint
#   make build-app APP=ops-build-image
#   make security        # Run security scans (checkov + trivy)
#   make status          # Show Waypoint deployment status
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: help
help: ## Show this help message
	@echo "Munchbox Docker Pipeline"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-25s %s\n", $$1, $$2}'

# ─────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────

REGISTRY_HOST ?= docker-mirror.service.consul
REGISTRY_PORT ?= 5000
REGISTRY      ?= $(REGISTRY_HOST):$(REGISTRY_PORT)
TAG           ?= latest
APP           ?=

# Image discovery: any directory with an app definition
APPS := $(patsubst %/,%,$(dir $(wildcard */*-waypoint-app.hcl)))

# ─────────────────────────────────────────────────────────────────────────
# Waypoint Tasks
# ─────────────────────────────────────────────────────────────────────────

.PHONY: generate-waypoint
generate-waypoint: ## Generate waypoint.hcl from header + app definitions
	@echo "Generating waypoint.hcl..."
	@{ \
	  cat waypoint-header.hcl; \
	  echo ""; \
	  cat */*-waypoint-app.hcl 2>/dev/null || true; \
	} > waypoint.hcl
	@echo "✅ Generated waypoint.hcl"

.PHONY: build
build: generate-waypoint ## Build all Docker images via Waypoint
	@echo "Building all images..."
	waypoint build

.PHONY: build-app
build-app: ## Build specific app (use APP=name)
	@if [ -z "$(APP)" ]; then \
	  echo "Error: APP not specified"; \
	  echo "Usage: make build-app APP=ops-build-image"; \
	  exit 1; \
	fi
	@echo "Building $(APP)..."
	waypoint build -app $(APP)

.PHONY: status
status: ## Show Waypoint deployment status
	waypoint status

.PHONY: deployments
deployments: ## List recent Waypoint deployments
	@echo "Recent deployments (limit=10):"
	waypoint deployment list -limit 10

.PHONY: apps
apps: ## List discovered Docker apps
	@echo "Discovered apps:"
	@for app in $(APPS); do \
	  echo "  • $$app"; \
	done

# ─────────────────────────────────────────────────────────────────────────
# Security Scanning
# ─────────────────────────────────────────────────────────────────────────

.PHONY: checkov
checkov: ## Scan Dockerfiles with Checkov
	@echo "Running Checkov on Dockerfiles..."
	@for app in $(APPS); do \
	  echo ""; \
	  echo "Checking $$app/Dockerfile..."; \
	  checkov -f "$$app/Dockerfile" || true; \
	done

.PHONY: trivy
trivy: ## Scan Dockerfiles and configs with Trivy
	@echo "Running Trivy on Dockerfiles..."
	@for app in $(APPS); do \
	  echo ""; \
	  echo "Scanning $$app/..."; \
	  trivy config --quiet "$$app" || true; \
	done

.PHONY: trivy-image
trivy-image: ## Scan built images with Trivy (fail on CRITICAL)
	@echo "Scanning built images for vulnerabilities..."
	@for app in $(APPS); do \
	  echo ""; \
	  echo "Scanning $(REGISTRY)/$$app:$(TAG)..."; \
	  trivy image --severity CRITICAL "$(REGISTRY)/$$app:$(TAG)" || exit 1; \
	done

.PHONY: security
security: checkov trivy ## Run all security scans

# ─────────────────────────────────────────────────────────────────────────
# Image Management
# ─────────────────────────────────────────────────────────────────────────

.PHONY: tag
tag: ## Tag images from latest to TAG
	@if [ "$(TAG)" = "latest" ]; then \
	  echo "Error: Cannot tag :latest to itself"; \
	  exit 1; \
	fi
	@echo "Tagging images :latest -> :$(TAG)..."
	@for app in $(APPS); do \
	  echo "  $(REGISTRY)/$$app:latest -> $(REGISTRY)/$$app:$(TAG)"; \
	  docker tag "$(REGISTRY)/$$app:latest" "$(REGISTRY)/$$app:$(TAG)"; \
	done

.PHONY: push
push: ## Push images to registry
	@echo "Pushing images with tag :$(TAG)..."
	@for app in $(APPS); do \
	  echo "  Pushing $(REGISTRY)/$$app:$(TAG)..."; \
	  docker push "$(REGISTRY)/$$app:$(TAG)"; \
	done

.PHONY: pull
pull: ## Pull images from registry
	@echo "Pulling images with tag :$(TAG)..."
	@for app in $(APPS); do \
	  echo "  Pulling $(REGISTRY)/$$app:$(TAG)..."; \
	  docker pull "$(REGISTRY)/$$app:$(TAG)"; \
	done

# ─────────────────────────────────────────────────────────────────────────
# Multi-Architecture Builds
# ─────────────────────────────────────────────────────────────────────────

PLATFORMS        ?= linux/amd64,linux/arm64
BUILDER_NAME     ?= munchbox-builder
BUILDKITD_CONFIG ?= .buildkitd.toml

.PHONY: buildx-setup
buildx-setup: ## Set up Docker BuildKit for multi-arch builds
	@echo "Setting up BuildKit for multi-arch..."
	@printf '[registry."%s"]\n  http = true\n  insecure = true\n' "$(REGISTRY)" > $(BUILDKITD_CONFIG)
	@docker buildx rm $(BUILDER_NAME) >/dev/null 2>&1 || true
	@docker run --privileged --rm tonistiigi/binfmt --install all >/dev/null 2>&1 || true
	@docker buildx create --driver docker-container --name $(BUILDER_NAME) --use --config $(BUILDKITD_CONFIG) >/dev/null
	@docker buildx inspect --bootstrap >/dev/null
	@echo "✅ BuildKit ready for $(PLATFORMS)"

.PHONY: publish-multiarch
publish-multiarch: buildx-setup generate-waypoint ## Build and push multi-arch images (amd64 + arm64)
	@echo "Publishing multi-arch images for $(PLATFORMS)..."
	@for app in $(APPS); do \
	  echo ""; \
	  echo "Building $$app for $(PLATFORMS)..."; \
	  docker buildx build "$$app" \
	    --platform $(PLATFORMS) \
	    -t "$(REGISTRY)/$$app:$(TAG)" \
	    --push || exit 1; \
	done
	@echo "✅ Published all images"

# ─────────────────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Clean generated files (waypoint.hcl, BuildKit config)
	@echo "Cleaning generated files..."
	@rm -f waypoint.hcl
	@rm -f $(BUILDKITD_CONFIG)
	@echo "✅ Cleaned"

.PHONY: clean-images
clean-images: ## Remove all locally built images
	@echo "Removing local images..."
	@for app in $(APPS); do \
	  docker rmi "$(REGISTRY)/$$app:$(TAG)" 2>/dev/null || true; \
	done
	@echo "✅ Removed"

# ─────────────────────────────────────────────────────────────────────────
# CI/CD Workflows
# ─────────────────────────────────────────────────────────────────────────

.PHONY: pr
pr: security build trivy-image ## CI for pull requests (security + build + scan)

.PHONY: merge
merge: pr tag push ## CD for merge to main (PR tasks + tag + push)
	@echo "✅ Merge pipeline complete"

# ═══════════════════════════════════════════════════════════════════════════
