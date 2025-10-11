# filepath: docker/Makefile
# ========================= SIMPLE TWO-TIER PIPELINE ==========================
# Run from docker/ (as your workflow does)

REGISTRY_HOST ?= docker-mirror.service.consul
REGISTRY_PORT ?= 5000
REGISTRY      ?= $(REGISTRY_HOST):$(REGISTRY_PORT)

# PR builds use :latest; merge sets TAG (e.g. TAG=${GITHUB_SHA}) and pushes it
TAG ?= latest

# Only include subdirs that actually contain a Dockerfile (keeps it simple)
IMAGES := $(patsubst %/Dockerfile,%, $(wildcard */Dockerfile))

.PHONY: checkov trivy build trivy-image tag push pull_request merge

# --- Orchestration -----------------------------------------------------------
# PR: checkov -> trivy -> build -> trivy-image
pull_request: checkov trivy build trivy-image

# Merge: PR tasks -> tag -> push
merge: pull_request tag push

# --- Steps -------------------------------------------------------------------
checkov:
	@echo "Checkov…"
	@for img in $(IMAGES); do \
		echo "  $$img/Dockerfile"; \
		checkov -f "$$img/Dockerfile"; \
	done

trivy:
	@echo "Trivy config…"
	@for img in $(IMAGES); do \
		echo "  $$img/Dockerfile"; \
		trivy config --quiet --file-patterns "dockerfile:Dockerfile" "$$img"; \
	done

# Always build as :latest for simplicity
build:
	@echo "Build images as :latest…"
	@for img in $(IMAGES); do \
		echo "  $(REGISTRY)/$$img:latest"; \
		docker build -t "$(REGISTRY)/$$img:latest" "$$img"; \
	done

# Scan the built :latest images; fail on CRITICAL
trivy-image:
	@echo "Trivy image scan (fail on CRITICAL)…"
	@for img in $(IMAGES); do \
		echo "  $(REGISTRY)/$$img:latest"; \
		trivy image --quiet --severity CRITICAL "$(REGISTRY)/$$img:latest"; \
	done

# On merge, create the release tag (e.g., TAG=${GITHUB_SHA}) from :latest
tag:
	@echo "Tag :latest -> :$(TAG)…"
	@for img in $(IMAGES); do \
		echo "  $(REGISTRY)/$$img:latest -> $(REGISTRY)/$$img:$(TAG)"; \
		docker tag "$(REGISTRY)/$$img:latest" "$(REGISTRY)/$$img:$(TAG)"; \
	done

# Push only the release tag
push:
	@echo "Push :$(TAG)…"
	@for img in $(IMAGES); do \
		echo "  $(REGISTRY)/$$img:$(TAG)"; \
		docker push "$(REGISTRY)/$$img:$(TAG)"; \
	done

