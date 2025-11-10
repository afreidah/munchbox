#!/bin/bash
# ===============================================================================
#  buildx-setup.sh
#  Ensures Docker buildx is configured for multi-arch builds
#  Run once at start of pipeline; idempotent
# ===============================================================================

set -e

BUILDER_NAME="${BUILDER_NAME:-munchbox-builder}"
REGISTRY_HOST="${REGISTRY_HOST:-docker-mirror.service.consul}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

echo "===> Validating buildx setup for multi-arch builds"

# Install binfmt support for cross-arch emulation
if command -v docker >/dev/null 2>&1; then
  echo "  Installing binfmt support..."
  docker run --privileged --rm tonistiigi/binfmt --install all >/dev/null 2>&1 || true
fi

# Check if builder exists; create if not
if ! docker buildx ls | grep -q "^$BUILDER_NAME"; then
  echo "  Creating buildx builder: $BUILDER_NAME"
  
  # Create buildkitd config to allow insecure registry
  cat > /tmp/buildkitd.toml <<EOF
[registry."${REGISTRY_HOST}:${REGISTRY_PORT}"]
  http = true
  insecure = true
EOF

  docker buildx create \
    --driver docker-container \
    --name "$BUILDER_NAME" \
    --use \
    --config /tmp/buildkitd.toml \
    >/dev/null

  echo "  Bootstrapping builder..."
  docker buildx inspect --bootstrap >/dev/null
else
  echo "  Builder $BUILDER_NAME already exists"
  docker buildx use "$BUILDER_NAME"
fi

echo "  Supported platforms: $PLATFORMS"
echo "✓ Buildx ready for: $PLATFORMS"
