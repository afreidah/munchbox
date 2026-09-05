# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: nomad_server
#
# Runs nomad in SERVER mode (server_enabled=true, client_enabled=false
# by default; flip client_enabled back on per-node for combined hosts).
#
# bootstrap_expect pinned to the current munchbox cluster size (3:
# goren, stabler, nomad-server-03). If a second nomad cluster ever
# appears, factor this back out into per-cluster roles.
#
# Per-node roles still need to set nomad.config.node_name + bind_addr +
# advertise_ip + server_join (per-cluster serf peer list).
# -------------------------------------------------------------------------------

name 'nomad_server'
description 'Installs + configures Nomad in server mode (3-node munchbox cluster)'

run_list(
  'recipe[nomad::install]',
  'recipe[nomad::configure]'
)

override_attributes(
  # --- Server mode is locked at this role layer; per-node defaults can't accidentally turn it off. ---
  nomad: {
    config: {
      server_enabled: true,
      bootstrap_expect: 3,
      gossip_encrypt_enabled: true,
    },
  }
)

default_attributes(
  # --- Pure-server default; per-node default_attributes flips this true for combined server+client hosts (Pi5s). ---
  nomad: {
    config: {
      client_enabled: false,
    },
  }
)
