#!/bin/bash
# ===============================================================================
#  pre-build.sh
#  Runs security scanning on Dockerfile and filesystem before building
#  Mapped into hook "before" { when = "build" }
# ===============================================================================

set -e

IMAGE_NAME="${WAYPOINT_APP_NAME:-unknown}"
DOCKERFILE_PATH="$(pwd)/${WAYPOINT_DOCKER_FILE:-Dockerfile}"

echo "===> Pre-build checks for $IMAGE_NAME"

# --- Checkov: Dockerfile static analysis ---
if command -v checkov >/dev/null 2>&1; then
  echo "  Checkov: scanning Dockerfile"
  checkov -f "$DOCKERFILE_PATH" --framework dockerfile --quiet || {
    echo "  ⚠ Checkov found issues (non-blocking)"
  }
else
  echo "  ⚠ checkov not installed; skipping"
fi

# --- Trivy: filesystem scan ---
if command -v trivy >/dev/null 2>&1; then
  echo "  Trivy: scanning filesystem"
  trivy config --quiet "$(dirname "$DOCKERFILE_PATH")" || {
    echo "  ⚠ Trivy found issues (non-blocking)"
  }
else
  echo "  ⚠ trivy not installed; skipping"
fi

echo "✓ Pre-build checks complete"
