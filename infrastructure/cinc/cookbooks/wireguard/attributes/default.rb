# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
# Attributes:: default
#
# Multi-interface configuration: nodes declare zero or more interfaces in
# `node[cookbook]['interfaces']`. The `configure` recipe iterates over the
# map and renders each one. Empty by default; nodes/roles override.
#
# Secret material (the local private_key + each peer's public_key) defaults
# to nil and gets pulled from Vault via `MunchboxLib::Vault.fetch` at
# converge time. For tests / dev, the same fields accept literal strings;
# whichever is set wins.
# -------------------------------------------------------------------------------

default[cookbook]['interfaces'] = {}

# -------------------------------------------------------------------------------
# System-level setup applied by `wireguard::install`.
# -------------------------------------------------------------------------------

default[cookbook]['install'] = {
  # --- iptables is the typical companion for PostUp/PostDown rules; override to drop it if you prefer nftables/ufw/firewalld directly ---
  packages: %w(wireguard wireguard-tools iptables),
  ip_forward: true,
}

# -------------------------------------------------------------------------------
# Static route to a remote WG network, applied by `wireguard::route`.
#
# Used on home-network nodes that need to reach the oracle WG mesh but
# aren't themselves WG peers. `gateway` defaults to the floating VIP held
# by the ingress node currently MASTER of keepalived's VI_WIREGUARD.
# Include the recipe in roles that need the route -- presence in the
# run_list IS the toggle. Don't include on:
#   - the gateway host itself (would route back to itself)
#   - nodes already covered by a wg interface AllowedIPs (oracle nodes)
# -------------------------------------------------------------------------------

default[cookbook]['route'] = {
  network: '10.200.0.0/24',
  gateway: '192.168.68.49',
  legacy_paths: %w(/etc/network/interfaces.d/wireguard-route),
}

# -------------------------------------------------------------------------------
# Host-side prep for nodes that run the wireguard-server nomad job (the
# ingress with the home-network VIP). Applied by `wireguard::ingress_prereqs`.
# -------------------------------------------------------------------------------

default[cookbook]['ingress_prereqs'] = {
  module_load_path: '/etc/modules-load.d/wireguard.conf',
  packages: %w(wireguard-tools),
  # --- Old keepalived vmac sysctls broke ARP across the Deco wired/wifi boundary; VIP no longer uses use_vmac so the drop-in is obsolete. Assert absent. ---
  stale_sysctls: %w(/etc/sysctl.d/99-keepalived-vmac.conf),
}
