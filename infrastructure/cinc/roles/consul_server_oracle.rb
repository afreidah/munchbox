# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: consul_server_oracle
#
# Runs consul in SERVER mode for the `oracle` datacenter. Added to the
# run_list of the oracle nodes chosen as servers (arm-1, arm-2, node-1),
# AFTER role[oracle_node] so it overrides the server=false that
# role[consul_client] locks in.
#
# Locks here (override, so the consul_client default can't win): server
# mode, the oracle quorum size, token replication from the primary, and
# the WAN serf peer list (the munchbox servers).
#
# Per-node node JSON still sets the identity bits: datacenter='oracle',
# primary_datacenter='munchbox', bind_addr + retry_join on the VCN
# (10.100.0.x), and advertise_addr_wan on the wg address munchbox reaches
# the server on.
# -------------------------------------------------------------------------------

name 'consul_server_oracle'
description 'Consul server for the oracle datacenter (3-node quorum, WAN-federated to munchbox)'

override_attributes(
  consul: {
    config: {
      server: true,
      bootstrap_expect: 3,
      enable_token_replication: true,
      retry_join_wan: %w(192.168.68.60 192.168.68.61 192.168.68.58),
    },
  }
)
