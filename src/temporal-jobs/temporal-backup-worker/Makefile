.PHONY: all build clean test worker trigger worker-arm trigger-arm install deploy update help

# Variables
BINARY_DIR = bin
WORKER_BINARY = $(BINARY_DIR)/worker
TRIGGER_BINARY = $(BINARY_DIR)/trigger
WORKER_BINARY_ARM = $(BINARY_DIR)/worker-arm64
TRIGGER_BINARY_ARM = $(BINARY_DIR)/trigger-arm64
INSTALL_DIR = /usr/local/bin

# Go parameters
GOCMD = go
GOBUILD = $(GOCMD) build
GOCLEAN = $(GOCMD) clean
GOTEST = $(GOCMD) test
GOGET = $(GOCMD) get
GOMOD = $(GOCMD) mod

# Build flags
LDFLAGS = -s -w

all: build

## build: Build all binaries (x86_64 and arm64)
build: worker trigger worker-arm trigger-arm
	@echo "✓ Build complete!"

## worker: Build worker binary (x86_64)
worker:
	@echo "Building worker (x86_64)..."
	@mkdir -p $(BINARY_DIR)
	GOOS=linux GOARCH=amd64 $(GOBUILD) -ldflags="$(LDFLAGS)" -o $(WORKER_BINARY) -tags worker .
	@chmod +x $(WORKER_BINARY)

## trigger: Build trigger binary (x86_64)
trigger:
	@echo "Building trigger (x86_64)..."
	@mkdir -p $(BINARY_DIR)
	GOOS=linux GOARCH=amd64 $(GOBUILD) -ldflags="$(LDFLAGS)" -o $(TRIGGER_BINARY) -tags trigger .
	@chmod +x $(TRIGGER_BINARY)

## worker-arm: Build worker binary (arm64)
worker-arm:
	@echo "Building worker (arm64)..."
	@mkdir -p $(BINARY_DIR)
	GOOS=linux GOARCH=arm64 $(GOBUILD) -ldflags="$(LDFLAGS)" -o $(WORKER_BINARY_ARM) -tags worker .
	@chmod +x $(WORKER_BINARY_ARM)

## trigger-arm: Build trigger binary (arm64)
trigger-arm:
	@echo "Building trigger (arm64)..."
	@mkdir -p $(BINARY_DIR)
	GOOS=linux GOARCH=arm64 $(GOBUILD) -ldflags="$(LDFLAGS)" -o $(TRIGGER_BINARY_ARM) -tags trigger .
	@chmod +x $(TRIGGER_BINARY_ARM)

## clean: Remove build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf $(BINARY_DIR)
	$(GOCLEAN)
	@echo "✓ Clean complete"

## test: Run tests
test:
	$(GOTEST) -v ./...

## deps: Download dependencies
deps:
	@echo "Downloading dependencies..."
	$(GOMOD) download
	$(GOMOD) tidy

## install: Install binaries to system
install: build
	@echo "Installing binaries to $(INSTALL_DIR)..."
	@sudo cp $(WORKER_BINARY) $(INSTALL_DIR)/temporal-backup-worker
	@sudo cp $(TRIGGER_BINARY) $(INSTALL_DIR)/temporal-backup-trigger
	@echo "✓ Installed to $(INSTALL_DIR)"

## deploy: Build binaries and deploy to all nodes
deploy: build
	@echo "Deploying binaries to nodes..."
	@for node in mccoy cabot; do \
		echo "  → Copying to $$node (x86_64)..."; \
		scp -q $(WORKER_BINARY) root@$$node:/usr/local/bin/temporal-backup-worker; \
		scp -q $(TRIGGER_BINARY) root@$$node:/usr/local/bin/temporal-backup-trigger; \
		ssh -q root@$$node "chmod +x /usr/local/bin/temporal-backup-*"; \
		echo "  ✓ $$node complete"; \
	done
	@for node in stabler goren; do \
		echo "  → Copying to $$node (arm64)..."; \
		scp -q $(WORKER_BINARY_ARM) root@$$node:/usr/local/bin/temporal-backup-worker; \
		scp -q $(TRIGGER_BINARY_ARM) root@$$node:/usr/local/bin/temporal-backup-trigger; \
		ssh -q root@$$node "chmod +x /usr/local/bin/temporal-backup-*"; \
		echo "  ✓ $$node complete"; \
	done
	@echo "✓ Deployment complete!"

## update: Stop job, deploy binaries, restart job
update: build
	@echo "Stopping temporal-backup-worker..."
	@nomad job stop -detach temporal-backup-worker || true
	@sleep 2
	@echo "Deploying binaries to nodes..."
	@for node in mccoy cabot; do \
		echo "  → Copying to $$node (x86_64)..."; \
		scp -q $(WORKER_BINARY) root@$$node:/usr/local/bin/temporal-backup-worker; \
		scp -q $(TRIGGER_BINARY) root@$$node:/usr/local/bin/temporal-backup-trigger; \
		ssh -q root@$$node "chmod +x /usr/local/bin/temporal-backup-*"; \
		echo "  ✓ $$node complete"; \
	done
	@for node in stabler goren; do \
		echo "  → Copying to $$node (arm64)..."; \
		scp -q $(WORKER_BINARY_ARM) root@$$node:/usr/local/bin/temporal-backup-worker; \
		scp -q $(TRIGGER_BINARY_ARM) root@$$node:/usr/local/bin/temporal-backup-trigger; \
		ssh -q root@$$node "chmod +x /usr/local/bin/temporal-backup-*"; \
		echo "  ✓ $$node complete"; \
	done
	@echo "Restarting temporal-backup-worker..."
	@cd ~/tools/munchbox/cdktf && nomad job run infra/nomad-jobs/backup/backup-worker.nomad.hcl
	@echo "✓ Update complete!"

## run-worker: Run worker locally
run-worker: worker
	@echo "Starting worker..."
	TEMPORAL_ADDRESS=192.168.68.61:7233 $(WORKER_BINARY)

## run-trigger: Trigger backup workflow locally
run-trigger: trigger
	@echo "Triggering backup..."
	TEMPORAL_ADDRESS=192.168.68.61:7233 $(TRIGGER_BINARY)

## dispatch: Manually dispatch Nomad job
dispatch:
	@echo "Dispatching backup job..."
	nomad job dispatch -detach temporal-backup-trigger

## help: Show this help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

.DEFAULT_GOAL := help
