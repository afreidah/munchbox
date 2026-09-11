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

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# WARP needs working DNS to reach the Cloudflare API, so a resolv.conf left
# pointing at the split-resolver by a failed run has to be undone before starting.
if ! dns_works; then
  restore_upstream_dns
  if ! dns_works; then
    echo "DNS is not resolving; fix networking before enabling WARP." >&2
    exit 1
  fi
fi

# Keep a copy while resolv.conf is still the upstream one; once the daemon
# starts it owns the file, and a copy taken later just captures WARP's stub.
stash_resolv

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

if ! wait_for_warp_daemon; then
  echo "CloudflareWARP daemon is not answering; check 'systemctl status $svc_name'." >&2
  exit 1
fi

# A Zero Trust profile that pins the mode refuses the switch even when it would
# be a no-op, so only ask when the current mode is one that does not route.
if ! warp_mode_routes; then
  # Pick the right subcommand for your warp-cli version
  if warp_cli help 2>/dev/null | grep -q 'set-mode'; then
    MODE_CMD="set-mode"
  else
    MODE_CMD="mode"
  fi

  if ! warp_cli "$MODE_CMD" warp; then
    echo "WARP is in a non-routing mode and the switch was refused; check the device profile's service mode." >&2
    exit 1
  fi
fi

# Connect (idempotent)
warp_cli connect

# Wait until we're actually connected (a stale registration refresh takes a while)
connected=0
for i in {1..60}; do
  if warp_cli status 2>/dev/null | grep -qE 'Status update: Connected([^a-zA-Z]|$)'; then
    connected=1
    echo "WARP is Connected."
    break
  fi
  sleep 1
done

# The split-resolver only answers for .consul and forwards the rest to WARP's DoH
# proxy, so pointing at it without a tunnel blackholes the DNS the next run needs.
if [[ "$connected" -ne 1 ]]; then
  echo "WARP never reached Connected; leaving resolv.conf alone." >&2
  warp_cli status 2>&1 || true
  exit 1
fi

# Route .consul lookups over the tunnel via the local dnsmasq split-resolver.
# (See /etc/dnsmasq.d/consul.conf.) Lock resolv.conf so WARP can't reclaim it.
if [[ -f /etc/dnsmasq.d/consul.conf ]]; then
  if ! wait_for_tunnel_dns; then
    echo "Tunnel is up but no Consul resolver answered; leaving resolv.conf alone." >&2
    exit 1
  fi

  sudo systemctl restart dnsmasq
  if ! systemctl is-active --quiet dnsmasq; then
    echo "dnsmasq failed to start; leaving resolv.conf alone." >&2
    exit 1
  fi
  ensure_split_resolv
fi

# Show interface summary (optional)
ip -4 addr show CloudflareWARP 2>/dev/null || true
