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

# Find the service name (varies by package)
svc_name=""
if systemctl list-unit-files | grep -q '^warp-svc'; then
  svc_name="warp-svc"
elif systemctl list-unit-files | grep -q '^cloudflare-warp'; then
  svc_name="cloudflare-warp"
fi

# Release the Consul split-DNS override BEFORE disconnecting, so WARP can
# restore the normal resolv.conf on its way down. dnsmasq is only needed
# while the tunnel is up, so stop it too.
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true

# Try to disconnect first (daemon must be running for this step)
warp-cli disconnect || true

# Optionally stop the daemon so the TUN device disappears
if [[ -n "$svc_name" ]]; then
  sudo systemctl stop "$svc_name" || true
fi

# Don't call warp-cli status here (daemon is stopped).
# Instead, show that the interface is gone:
if ip link show CloudflareWARP &>/dev/null; then
  echo "CloudflareWARP interface still present."
else
  echo "CloudflareWARP interface is down."
fi
