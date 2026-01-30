# -------------------------------------------------------------------------------
# Oracle Watchdog - Makefile
#
# Project: Munchbox / Author: Alex Freidah
#
# Build targets for the Oracle node watchdog. Supports native and cross-
# compilation, Debian package generation via nfpm, and lintian validation.
# -------------------------------------------------------------------------------

.PHONY: help build build-linux build-linux-arm64 build-all clean \
        build-deb build-deb-arm64 lint-deb prep-changelog \
        docker-build docker-push publish-deb test

# --- Build variables ---
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "1.0.0")
COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "none")
BUILD_TIME ?= $(shell date -u '+%Y-%m-%d_%H:%M:%S')
DEB_VERSION ?= $(shell v="$(VERSION)"; if echo "$$v" | grep -qE '^[0-9]'; then echo "$$v"; else echo "1.0.0+$$v"; fi)

# --- Go toolchain ---
GOCMD = go
GOBUILD = CGO_ENABLED=0 $(GOCMD) build
LDFLAGS = -ldflags "-s -w -X main.Version=$(VERSION) -X main.Commit=$(COMMIT)"

# --- Output paths ---
BINARY = oracle-watchdog
BINARY_PATH = ./cmd/watchdog
BIN_DIR = ./bin
DEB_DIR = ./dist

default: help

# Show available targets
help:
	@echo "Available targets:"
	@echo ""
	@echo "  build             Build for current platform"
	@echo "  build-linux       Build for Linux amd64"
	@echo "  build-linux-arm64 Build for Linux arm64"
	@echo "  build-all         Build for all Linux platforms"
	@echo "  test              Run all tests"
	@echo "  build-deb         Build Debian package for amd64"
	@echo "  build-deb-arm64   Build Debian package for arm64"
	@echo "  lint-deb          Run lintian on built packages"
	@echo "  publish-deb       Publish packages to Aptly repo"
	@echo "  clean             Remove build artifacts"
	@echo ""

# -------------------------------------------------------------------------
# BUILD TARGETS
# -------------------------------------------------------------------------

# Build for current platform
build:
	$(GOBUILD) $(LDFLAGS) -o $(BIN_DIR)/$(BINARY) $(BINARY_PATH)

# Build for Linux amd64
build-linux:
	GOOS=linux GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o $(BIN_DIR)/$(BINARY)-linux-amd64 $(BINARY_PATH)

# Build for Linux arm64
build-linux-arm64:
	GOOS=linux GOARCH=arm64 $(GOBUILD) $(LDFLAGS) -o $(BIN_DIR)/$(BINARY)-linux-arm64 $(BINARY_PATH)

# Build for all platforms
build-all: build-linux build-linux-arm64

# -------------------------------------------------------------------------
# TESTING
# -------------------------------------------------------------------------

# Run all tests
test:
	$(GOCMD) test -v ./...

# -------------------------------------------------------------------------
# DEBIAN PACKAGING
# -------------------------------------------------------------------------

# Prepare changelog for Debian packaging
prep-changelog:
	@gzip -9 -n -c packaging/changelog > packaging/changelog.gz

# Build Debian package for amd64
build-deb: build-linux prep-changelog
	@mkdir -p $(DEB_DIR)
	@cp $(BIN_DIR)/$(BINARY)-linux-amd64 $(BIN_DIR)/$(BINARY)-linux
	VERSION=$(DEB_VERSION) GOARCH=amd64 nfpm package --packager deb --target $(DEB_DIR)/
	@rm -f $(BIN_DIR)/$(BINARY)-linux

# Build Debian package for arm64
build-deb-arm64: build-linux-arm64 prep-changelog
	@mkdir -p $(DEB_DIR)
	@cp $(BIN_DIR)/$(BINARY)-linux-arm64 $(BIN_DIR)/$(BINARY)-linux
	VERSION=$(DEB_VERSION) GOARCH=arm64 nfpm package --packager deb --target $(DEB_DIR)/
	@rm -f $(BIN_DIR)/$(BINARY)-linux

# Lint Debian packages with lintian (uses Docker on macOS)
lint-deb:
ifeq ($(shell uname),Darwin)
	@for deb in $(DEB_DIR)/*.deb; do \
		echo "Linting $$deb (via Docker)..."; \
		docker run --rm -v $(CURDIR)/$(DEB_DIR):/pkg debian:bookworm-slim \
			sh -c "apt-get update -qq && apt-get install -qq -y lintian >/dev/null 2>&1 && lintian --verbose /pkg/$$(basename $$deb)" || true; \
	done
else
	@for deb in $(DEB_DIR)/*.deb; do \
		echo "Linting $$deb..."; \
		lintian --verbose $$deb || true; \
	done
endif

# -------------------------------------------------------------------------
# APTLY PUBLISHING
# -------------------------------------------------------------------------

APTLY_URL ?= https://apt.munchbox.cc
APTLY_REPO ?= munchbox
APTLY_USER ?= admin
SNAPSHOT_NAME ?= $(BINARY)-$(shell date +%Y%m%d-%H%M%S)

# Publish .deb packages to Aptly repository
publish-deb:
	@if [ -z "$(APTLY_PASS)" ]; then echo "Error: APTLY_PASS not set (source munchbox-env.sh)"; exit 1; fi
	@echo "Publishing packages to $(APTLY_URL)..."
	@for deb in $(DEB_DIR)/*.deb; do \
		echo "Uploading $$(basename $$deb)..."; \
		curl -fsS -u "$(APTLY_USER):$(APTLY_PASS)" \
			-X POST -F "file=@$$deb" \
			"$(APTLY_URL)/api/files/$(BINARY)" || exit 1; \
	done
	@echo "Adding packages to repo $(APTLY_REPO)..."
	@curl -fsS -u "$(APTLY_USER):$(APTLY_PASS)" \
		-X POST "$(APTLY_URL)/api/repos/$(APTLY_REPO)/file/$(BINARY)" || exit 1
	@echo "Creating snapshot $(SNAPSHOT_NAME)..."
	@curl -fsS -u "$(APTLY_USER):$(APTLY_PASS)" \
		-X POST -H 'Content-Type: application/json' \
		-d '{"Name":"$(SNAPSHOT_NAME)"}' \
		"$(APTLY_URL)/api/repos/$(APTLY_REPO)/snapshots" || exit 1
	@echo "Updating published repo..."
	@curl -fsS -u "$(APTLY_USER):$(APTLY_PASS)" \
		-X PUT -H 'Content-Type: application/json' \
		-d '{"Snapshots":[{"Component":"main","Name":"$(SNAPSHOT_NAME)"}],"ForceOverwrite":true}' \
		'$(APTLY_URL)/api/publish/:./stable' || exit 1
	@echo "Cleaning up uploaded files..."
	@curl -fsS -u "$(APTLY_USER):$(APTLY_PASS)" \
		-X DELETE "$(APTLY_URL)/api/files/$(BINARY)" || true
	@echo "Published successfully!"

# -------------------------------------------------------------------------
# DOCKER
# -------------------------------------------------------------------------

REGISTRY ?= registry.munchbox.cc
IMAGE_NAME ?= oracle-watchdog
IMAGE_TAG ?= $(VERSION)

# Build multi-arch docker image
docker-build:
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		.

# Build and push multi-arch docker image
docker-push:
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		--push .

# -------------------------------------------------------------------------
# CLEANUP
# -------------------------------------------------------------------------

# Clean build artifacts
clean:
	rm -rf $(BIN_DIR) $(DEB_DIR)
	rm -f packaging/changelog.gz

