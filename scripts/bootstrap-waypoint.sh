#!/bin/bash
# ===============================================================================
#  bootstrap-waypoint.sh
#  SSH to mccoy, bootstrap waypoint server, extract token, save to shared volume
# ===============================================================================

set -e

echo "==> Connecting to mccoy and bootstrapping Waypoint server..."

ssh mccoy << 'EOF'
  set -e
  
  echo "  Finding waypoint-server container..."
  CONTAINER_ID=$(sudo docker ps | grep ops-waypoint-image | awk '{print $1}' | head -1)
  
  echo "  Container: $CONTAINER_ID"
  
  echo "  Bootstrapping server (this may take a moment)..."
  sudo docker exec "$CONTAINER_ID" waypoint server bootstrap -server-addr=mccoy:9701 -server-tls-skip-verify
  
  echo ""
  echo "✓ Bootstrap complete"
  
  # Manually extract from last bootstrap
  TOKEN_FILE="/opt/nomad/data/waypoint-data/waypoint-token"
  if [ -f "$TOKEN_FILE" ]; then
    echo "✓ Token already exists at $TOKEN_FILE"
    cat "$TOKEN_FILE"
  fi
EOF
