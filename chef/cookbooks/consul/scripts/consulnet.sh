#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# consulnet.sh — Create or delete the Docker network for Test Kitchen Consul
#
# Usage:
#   ./consulnet.sh create   # Create consulnet (172.28.0.0/16)
#   ./consulnet.sh delete   # Delete consulnet
#   ./consulnet.sh inspect  # Show network details
# ------------------------------------------------------------------------------

set -euo pipefail

NETWORK_NAME="consulnet"
SUBNET="172.28.0.0/16"

case "${1:-}" in
  create)
    echo "[INFO] Creating Docker network: $NETWORK_NAME ($SUBNET)"
    if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
      echo "[WARN] Network '$NETWORK_NAME' already exists — skipping."
    else
      docker network create \
        --driver=bridge \
        --subnet="$SUBNET" \
        "$NETWORK_NAME"
      echo "[OK] Network '$NETWORK_NAME' created."
    fi
    ;;
  delete)
    echo "[INFO] Deleting Docker network: $NETWORK_NAME"
    if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
      docker network rm "$NETWORK_NAME"
      echo "[OK] Network '$NETWORK_NAME' removed."
    else
      echo "[WARN] Network '$NETWORK_NAME' does not exist — skipping."
    fi
    ;;
  inspect)
    docker network inspect "$NETWORK_NAME" || {
      echo "[WARN] Network '$NETWORK_NAME' does not exist."
      exit 1
    }
    ;;
  *)
    echo "Usage: $0 {create|delete|inspect}"
    exit 1
    ;;
esac
