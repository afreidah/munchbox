# filepath: docker/Makefile
# ========================= SIMPLE TWO-TIER PIPELINE ==========================

REGISTRY_HOST ?= docker-mirror.service.consul
REGISTRY_PORT ?= 5000
REGISTRY      ?= $(REGISTRY_HOST):$(REGISTRY_PORT)

# On PR we always build/tag as :latest; on merge we create :$(TAG) from :latest
TAG ?= latest

IMAGES := $(patsubst %/,%,$(wildcard */))

.PHONY: checkov trivy build trivy-image tag push pull_request merge

# PR: checkov -> trivy -> build -> trivy-image
pull_request: checkov trivy build trivy-image

# Merge: PR tasks -> tag -> push
merge: pull_request tag push

checkov:
	@echo "Checkov…"
	@for img in $(IMAGES); do \
		checkov -f "$$img/Dockerfile"; \
	done

trivy:
	@echo "Trivy config…"
	@for img in $(IMAGES); do \
		trivy config --quiet --file-patterns "dockerfile:Dockerfile" "$$img"; \
	done

# Always build as :latest for simplicity
build:
	@echo "Build images as :latest…"
	@for img in $(IMAGES); do \
		docker build -t "$(REGISTRY)/$$img:latest" "$$img"; \
	done

# Scan the built :latest images; fail on CRITICAL
trivy-image:
	@echo "Trivy image scan (fail on CRITICAL)…"
	@for img in $(IMAGES); do \
		trivy image --quiet --severity CRITICAL "$(REGISTRY)/$$img:latest"; \
	done

# On merge, create the release tag (e.g., TAG=${GITHUB_SHA}) from :latest
tag:
	@echo "Tag :latest -> :$(TAG)…"
	@for img in $(IMAGES); do \
		docker tag "$(REGISTRY)/$$img:latest" "$(REGISTRY)/$$img:$(TAG)"; \
	done

# Push only the release tag
push:
	@echo "Push :$(TAG)…"
	@for img in $(IMAGES); do \
		docker push "$(REGISTRY)/$$img:$(TAG)"; \
	done

