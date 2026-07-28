# -----------------------------------------------------------------------------
# Shared image build/push targets for Munchbox container images.
#
# Each image dir's Makefile sets IMAGE (plus any overrides) then:
#   include ../_common.mk
#
# Every build stamps :latest (mutable), :<git-sha> (immutable, for rollbackable
# deploys), plus any EXTRA_TAGS the image declares. Run any target from inside
# an image dir, or with `make -C docker/<image> <target>`.
#
# Run `make help` for the current target list.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# --- Required (set before include) ---
#   IMAGE        image name under $(REGISTRY)
# --- Optional overrides (set before include) ---
#   REGISTRY     registry host                       (default registry.munchbox.cc)
#   TAG          mutable tag                          (default latest)
#   PLATFORMS    push target platforms                (default linux/amd64,linux/arm64)
#   EXTRA_TAGS   additional tags to stamp             (e.g. pg18 pg18-patroni4.0.4)
#   CACHE        set to 1 to enable registry build cache
#   CONTEXT      docker build context                 (default .)

REGISTRY   ?= registry.munchbox.cc
TAG        ?= latest
PLATFORMS  ?= linux/amd64,linux/arm64
CONTEXT    ?= .
BUILDER    := munchbox-builder

# --- Immutable per-build tag: short git sha, suffixed -dirty when this image's
#     build context has uncommitted changes (scoped to CONTEXT, not the whole repo) ---
GIT_SHA    := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)$(shell git diff --quiet HEAD -- $(CONTEXT) 2>/dev/null || echo -dirty)
FULL_IMAGE := $(REGISTRY)/$(IMAGE)
IMAGE_TAGS := $(TAG) $(GIT_SHA) $(EXTRA_TAGS)
TAG_FLAGS  := $(foreach t,$(IMAGE_TAGS),-t $(FULL_IMAGE):$(t))

# --- Optional registry build cache ---
comma := ,
ifdef CACHE
CACHE_REF  := $(FULL_IMAGE):cache
CACHE_FROM := --cache-from type=registry$(comma)ref=$(CACHE_REF)
CACHE_TO   := --cache-to type=registry$(comma)ref=$(CACHE_REF)$(comma)mode=max
endif

.DEFAULT_GOAL := help
.PHONY: help builder build build-multiarch push sha tags clean

help: ## Display available Make targets
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(IMAGE) image build\n\nUsage: make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z0-9_-]+:.*?## / { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

builder: ## Ensure the shared buildx builder exists
	@docker buildx inspect $(BUILDER) >/dev/null 2>&1 || \
		docker buildx create --name $(BUILDER) --driver-opt network=host --use

build: ## Build for the local architecture (fresh base pull)
	docker build --pull $(TAG_FLAGS) $(CONTEXT)

build-multiarch: builder ## Build for the current platform into the local daemon
	docker buildx build --pull $(CACHE_FROM) $(TAG_FLAGS) --load $(CONTEXT)

push: builder ## Build and push $(PLATFORMS) to the registry
	docker buildx build --pull --platform $(PLATFORMS) \
		$(CACHE_FROM) $(CACHE_TO) $(TAG_FLAGS) --push $(CONTEXT)

sha: ## Print the immutable git-sha image ref (paste into the Nomad job)
	@echo $(FULL_IMAGE):$(GIT_SHA)

tags: ## List every tag this build would stamp
	@printf '$(FULL_IMAGE):%s\n' $(IMAGE_TAGS)

clean: ## Remove local images for this build
	@docker rmi $(foreach t,$(IMAGE_TAGS),$(FULL_IMAGE):$(t)) 2>/dev/null || true
