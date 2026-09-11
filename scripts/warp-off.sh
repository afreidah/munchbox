#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# WARP Off - Disable Cloudflare WARP VPN
#
# Project: Munchbox / Author: Alex Freidah
#
# Disables Cloudflare WARP VPN tunnel and stops the daemon. Handles both
# warp-svc and cloudflare-warp service names across package versions.
# -------------------------------------------------------------------------------
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Find the service name (varies by package)
svc_name=""
if systemctl list-unit-files | grep -q '^warp-svc'; then
  svc_name="warp-svc"
elif systemctl list-unit-files | grep -q '^cloudflare-warp'; then
  svc_name="cloudflare-warp"
fi

# Release the Consul split-DNS override before stopping the resolver behind it.
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true

# Try to disconnect first (daemon must be running for this step)
warp_cli disconnect || true

# Optionally stop the daemon so the TUN device disappears
if [[ -n "$svc_name" ]]; then
  sudo systemctl stop "$svc_name" || true
fi

# Last, so the daemon cannot rewrite resolv.conf after we put the original back.
restore_upstream_dns

# Don't call warp-cli status here (daemon is stopped).
# Instead, show that the interface is gone:
if ip link show CloudflareWARP &>/dev/null; then
  echo "CloudflareWARP interface still present."
else
  echo "CloudflareWARP interface is down."
fi
