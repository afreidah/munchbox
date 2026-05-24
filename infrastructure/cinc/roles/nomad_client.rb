# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: nomad_client
#
# Runs nomad in CLIENT mode only. Bundles nomad::install + nomad::configure
# and locks server_enabled=false at the role layer so a per-node attribute
# can't accidentally flip a client into a server.
#
# Per-node roles still need to set nomad.config.node_name + bind_addr +
# advertise_ip (those are per-node). Per-cluster shared attrs (servers
# list, node_pool, network_interface, client_meta) belong in the
# wrapping role (e.g. role[oracle_node]).
# -------------------------------------------------------------------------------

name 'nomad_client'
description 'Installs + configures Nomad in client mode'

run_list(
  'recipe[nomad::install]',
  'recipe[nomad::configure]'
)

override_attributes(
  nomad: {
    config: {
      server_enabled: false,
      client_enabled: true,
    },
  }
)
