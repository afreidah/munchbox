#!/bin/bash
# ===============================================================================
#  build-scan-release.sh
#  Orchestrates: build → tag → scan → release workflow
# ===============================================================================

set -e

APP=${1:-ops-build-image}
TAG=${2:-latest}
REGISTRY_HOST=${REGISTRY_HOST:-docker-mirror.service.consul}
REGISTRY_PORT=${REGISTRY_PORT:-5000}
FULL_IMAGE="${REGISTRY_HOST}:${REGISTRY_PORT}/${APP}:${TAG}"

echo "=========================================================="
echo "  Build + Scan + Release: $APP:$TAG"
echo "=========================================================="

# 1. Build (local)
echo ""
echo "» Step 1: Building locally..."
waypoint build -app "$APP"

# 2. Tag for registry
echo ""
echo "» Step 2: Tagging image..."
LOCAL_IMAGE="waypoint.local/${APP}:${TAG}"
docker tag "$LOCAL_IMAGE" "$FULL_IMAGE"
echo "  Tagged: $LOCAL_IMAGE → $FULL_IMAGE"

# 3. Scan locally
echo ""
echo "» Step 3: Scanning with Trivy..."
if command -v trivy >/dev/null; then
  trivy image --quiet "$FULL_IMAGE" || echo "  ⚠ Issues found (review above)"
else
  echo "  ⚠ trivy not installed"
fi

# 4. Release (push)
echo ""
echo "» Step 4: Pushing to registry..."
docker push "$FULL_IMAGE"

echo ""
echo "=========================================================="
echo "✓ Complete: $FULL_IMAGE"
echo "=========================================================="
