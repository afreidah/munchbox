# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
# Recipe:: route
#
# Adds a static route to a remote WireGuard network (e.g. the oracle
# `10.200.0.0/24` mesh) via a gateway IP that's typically the
# keepalived-managed floating VIP held by whichever ingress node is
# currently MASTER. Used on home-network nodes (proxmox VMs, bare-metal
# servers) that need to reach WG peers but aren't themselves part of the
# tunnel.
#
# Skip with a guard in the per-node role (or attribute) on:
#   - the gateway host itself (would route back to itself)
#   - nodes that already have a wg interface covering the same subnet
# -------------------------------------------------------------------------------

cfg = node[cookbook]['route']

wireguard_route 'baseline' do
  network cfg['network']
  gateway cfg['gateway']
  legacy_paths cfg['legacy_paths']
end
