.PHONY: build push clean test help

REGISTRY ?= registry.munchbox.cc
IMAGE_NAME = trivy-dashboard
IMAGE_TAG ?= latest
IMAGE = $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

build:
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE) .

push:
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE) --push .

clean:
	go clean

test:
	go test -v ./...

help:
	@echo "make build  - Build multi-arch image (amd64 + arm64)"
	@echo "make push   - Build and push multi-arch image to registry"
	@echo "make clean  - Remove build artifacts"
	@echo "make test   - Run tests"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_TAG=latest  - Image tag (default: latest)"

.DEFAULT_GOAL := help
