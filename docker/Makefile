# filepath: docker/Makefile

# use consul dns to find the service
REGISTRY = docker-mirror.service.consul

# Normalize subdir list to names without trailing slash (e.g. "deluge-vpn", "ops-build-image")
IMAGES := $(patsubst %/,%,$(wildcard */))

.PHONY: checkov trivy trivy-image build push all

all: checkov trivy build push

# ------------------------------------------------------------------------------
# Checkov: scan Dockerfiles
# ------------------------------------------------------------------------------
checkov:
	@echo "Scanning Dockerfiles with Checkov..."
	@for img in $(IMAGES); do \
		echo "Checking $$img/Dockerfile"; \
		checkov -f "$$img/Dockerfile"; \
	done

# ------------------------------------------------------------------------------
# Trivy (config): scan Dockerfiles for misconfigurations
#   - This runs before build/push and does NOT require images to exist.
#   - The file-patterns selector tells Trivy to parse Dockerfiles.
# ------------------------------------------------------------------------------
trivy:
	@echo "Scanning Dockerfiles with Trivy (config scan)..."
	@for img in $(IMAGES); do \
		echo "Scanning $$img/Dockerfile"; \
		trivy config --quiet --file-patterns "dockerfile:Dockerfile" "$$img"; \
	done

# ------------------------------------------------------------------------------
# Optional: Trivy (image) scan — requires images to be built first
#   - Use after `make build` or wire a dependency: trivy-image: build
# ------------------------------------------------------------------------------
trivy-image: build
	@echo "Scanning built images with Trivy (image scan)..."
	@for img in $(IMAGES); do \
		echo "Scanning $(REGISTRY)/$$img:latest"; \
		trivy image --quiet --severity CRITICAL "$(REGISTRY)/$$img:latest"; \
	done

# ------------------------------------------------------------------------------
# Build & Push — fixed the shell var assignment pattern
# ------------------------------------------------------------------------------
build:
	@echo "Building Docker images..."
	@for img in $(IMAGES); do \
		echo "Building $(REGISTRY)/$$img:latest"; \
		docker build -t "$(REGISTRY)/$$img:latest" "$$img"; \
	done

push:
	@echo "Pushing Docker images to registry..."
	@for img in $(IMAGES); do \
		echo "Pushing $(REGISTRY)/$$img:latest"; \
		docker push "$(REGISTRY)/$$img:latest"; \
	done
