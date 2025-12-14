#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# WARP On - Enable Cloudflare WARP VPN
#
# Project: Munchbox / Author: Alex Freidah
#
# Enables Cloudflare WARP VPN tunnel for private network access. Handles both
# warp-svc and cloudflare-warp service names across package versions.
# -------------------------------------------------------------------------------
set -euo pipefail

# Find the service name (varies by package)
svc_name=""
if systemctl list-unit-files | grep -q '^warp-svc'; then
  svc_name="warp-svc"
elif systemctl list-unit-files | grep -q '^cloudflare-warp'; then
  svc_name="cloudflare-warp"
fi

# Ensure daemon is up (if we have systemd)
if [[ -n "$svc_name" ]]; then
  sudo systemctl start "$svc_name"
fi

# Pick the right subcommand for your warp-cli version
if warp-cli help 2>/dev/null | grep -q 'set-mode'; then
  MODE_CMD="set-mode"
else
  MODE_CMD="mode"
fi

# Use full-tunnel WARP (best for private routing)
warp-cli "$MODE_CMD" warp || true

# Connect (idempotent)
warp-cli connect

# Wait until we're actually connected (up to ~10s)
for i in {1..20}; do
  s=$(warp-cli status 2>/dev/null || true)
  if echo "$s" | grep -qi 'Connected'; then
    echo "WARP is Connected."
    break
  fi
  sleep 0.5
done

# Show interface summary (optional)
ip -4 addr show CloudflareWARP 2>/dev/null || true
