#!/bin/bash
# -----------------------------------------------------------------------------
# Consul Service Registration Script
#
# Project: Munchbox / Author: Alex Freidah
#
# For each JSON service definition in /etc/consul-register/, probe the
# embedded .Check.Definition.HTTP locally, build the catalog-register
# payload with .Check.Status = passing|critical based on the probe, and
# POST to consul's /v1/catalog/register.
#
# Replaces the prior hardcoded-"Status":"passing" pattern (was bug #30).
# Pi-zero hosts can't run a consul agent, so the probe-and-push happens
# from this systemd timer instead. Lossy compared to a real agent check
# but at least the catalog reflects actual reachability within the
# 5-minute timer interval.
# -----------------------------------------------------------------------------

set -euo pipefail

CONSUL_ADDR="${CONSUL_ADDR:-http://192.168.68.61:8500}"
REGISTER_DIR="${REGISTER_DIR:-/etc/consul-register}"

command -v jq >/dev/null || { echo "jq missing; apt-get install -y jq" >&2; exit 1; }

# --- Probe the URL; print passing|critical (warning never used here) ---
probe_status() {
  local url=$1 timeout=${2:-5}
  if curl -sf -o /dev/null -m "$timeout" "$url"; then
    echo passing
  else
    echo critical
  fi
}

shopt -s nullglob
for service_file in "$REGISTER_DIR"/*.json; do
  name=$(basename "$service_file")
  url=$(jq -r '.Check.Definition.HTTP // empty' "$service_file")
  if [[ -z "$url" ]]; then
    # No check -- POST as-is; consul stores it without a check.
    payload=$(cat "$service_file")
    status='(no check)'
  else
    status=$(probe_status "$url")
    payload=$(jq --arg s "$status" '.Check.Status = $s' "$service_file")
  fi

  echo "Registering $name [status=$status]..."
  curl -sS -f -o /dev/null \
    -X PUT -H 'Content-Type: application/json' \
    -d "$payload" \
    "$CONSUL_ADDR/v1/catalog/register" \
    || echo "  POST failed for $name"
done

echo "Service registration complete for $(hostname -s)"
