#!/bin/bash
# ===============================================================================
#  pre-release.sh
#  Scans built Docker image for vulnerabilities (CRITICAL only)
#  Mapped into hook "before" { when = "release" }
#  Blocks release if CRITICAL vulns found
# ===============================================================================

set -e

IMAGE_NAME="${WAYPOINT_APP_NAME:-unknown}"
IMAGE_TAG="${WAYPOINT_RELEASE_TAG:-latest}"
REGISTRY_HOST="${REGISTRY_HOST:-docker-mirror.service.consul}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
REGISTRY="${REGISTRY_HOST}:${REGISTRY_PORT}"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "===> Pre-release image scan: $FULL_IMAGE"

if ! command -v trivy >/dev/null 2>&1; then
  echo "⚠ trivy not installed; skipping image scan"
  exit 0
fi

# Scan with CRITICAL severity (fail on CRITICAL)
echo "  Scanning for CRITICAL vulnerabilities..."
if trivy image --quiet --severity CRITICAL "$FULL_IMAGE"; then
  echo "✓ No CRITICAL vulnerabilities found"
else
  EXIT_CODE=$?
  echo "✗ CRITICAL vulnerabilities detected in $IMAGE_NAME"
  echo "  Fix vulnerabilities before pushing to registry"
  exit $EXIT_CODE
fi

# Optional: full vulnerability summary (non-blocking)
echo "  Full vulnerability summary:"
trivy image --quiet "$FULL_IMAGE" | tail -20 || true

echo "✓ Image scan complete"
