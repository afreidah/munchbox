#!/usr/bin/env bash
set -euo pipefail

# --- Preconditions ---
command -v curl >/dev/null 2>&1 || { echo "curl not found in image"; exit 1; }
command -v nc   >/dev/null 2>&1 || { echo "netcat not found in image"; exit 1; }

# --- Port/host resolution (no ${...} to avoid HCL interpolation traps) ---
HOST_GRPC="$NOMAD_IP_grpc"
if [ -z "$HOST_GRPC" ]; then HOST_GRPC="127.0.0.1"; fi

PORT_GRPC="$NOMAD_HOST_PORT_grpc"
if [ -z "$PORT_GRPC" ]; then PORT_GRPC="9701"; fi

HOST_UI="$NOMAD_IP_ui"
if [ -z "$HOST_UI" ]; then HOST_UI="127.0.0.1"; fi

PORT_UI="$NOMAD_HOST_PORT_ui"
if [ -z "$PORT_UI" ]; then PORT_UI="9702"; fi

# --- Wait for gRPC ---
echo "Waiting for Waypoint gRPC on $HOST_GRPC:$PORT_GRPC ..."
for i in $(seq 1 300); do
  if nc -z "$HOST_GRPC" "$PORT_GRPC" 2>/dev/null; then
    echo "gRPC is up"
    break
  fi
  if [ $((i % 30)) -eq 0 ]; then echo "Still waiting... ($i/300)"; fi
  sleep 1
done
nc -z "$HOST_GRPC" "$PORT_GRPC" 2>/dev/null || { echo "gRPC never became reachable"; exit 1; }

# --- UI probe (non-blocking) ---
curl -fsS "http://$HOST_UI:$PORT_UI/" >/dev/null 2>&1 || echo "UI not responding yet; proceeding because gRPC is up."

# --- Bootstrap ---
export WAYPOINT_SERVER_ADDR="$HOST_GRPC:$PORT_GRPC"
export WAYPOINT_SERVER_TLS=0

set +e
BOOTSTRAP_OUT="$(waypoint server bootstrap -server-addr "$WAYPOINT_SERVER_ADDR" 2>&1)"
BOOTSTRAP_RC=$?
set -e

echo "$BOOTSTRAP_OUT"
if [ "$BOOTSTRAP_RC" -ne 0 ]; then
  echo "Bootstrap failed (rc=$BOOTSTRAP_RC); not writing anything to Vault."
  exit 1
fi

TOKEN="$(printf "%s\n" "$BOOTSTRAP_OUT" | awk 'NF{last=$0} END{print last}' | tr -d '\r\n')"
if [ -z "$TOKEN" ]; then
  echo "No token parsed from bootstrap output; aborting."
  exit 1
fi

# --- Vault write (KV v2) ---
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
  echo "VAULT_ADDR or VAULT_TOKEN not present; cannot write to Vault."
  exit 1
fi

echo "Writing token to Vault KV v2 path: secret/data/system-services/waypoint_server_token"
curl -sSf \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"data\":{\"token\":\"$TOKEN\"}}" \
  "$VAULT_ADDR/v1/secret/data/system-services/waypoint_server_token" >/dev/null

echo "Token stored."
