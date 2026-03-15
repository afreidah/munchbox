# -------------------------------------------------------------------------------
# Personal Site - Build and Push
#
# Author: Alex Freidah
#
# Static landing page for alexfreidah.com. Plain HTML/CSS served by nginx.
# -------------------------------------------------------------------------------

REGISTRY   ?= registry.munchbox.cc
IMAGE      := personal-site
VERSION    ?= $(shell cat .version)

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
		awk 'BEGIN {FS = ":.*?## "} {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""

# -------------------------------------------------------------------------
# BUILDX SETUP
# -------------------------------------------------------------------------

builder: ## Ensure the Buildx builder exists
	@docker buildx inspect site-builder >/dev/null 2>&1 || \
		docker buildx create --name site-builder --driver-opt network=host --use
	@docker buildx inspect --bootstrap

# -------------------------------------------------------------------------
# DOCKER
# -------------------------------------------------------------------------

docker: ## Build Docker image for local architecture
	@echo "Building $(FULL_TAG) for local architecture"
	docker build --pull -t $(FULL_TAG) .

push: builder ## Build and push multi-arch images to registry
	@echo "Building and pushing $(FULL_TAG) for $(PLATFORMS)"
	docker buildx build \
	  --pull \
	  --platform $(PLATFORMS) \
	  -t $(FULL_TAG) \
	  --output type=image,push=true \
	  .

# -------------------------------------------------------------------------
# DEVELOPMENT
# -------------------------------------------------------------------------

serve: ## Serve locally with Python HTTP server
	cd static && python3 -m http.server 8080

# -------------------------------------------------------------------------
# CLEANUP
# -------------------------------------------------------------------------

clean: ## Remove build artifacts
	docker rmi $(FULL_TAG) 2>/dev/null || true

.PHONY: help builder docker push serve clean
.DEFAULT_GOAL := help
