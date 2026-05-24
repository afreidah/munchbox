# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: consul_client
#
# Runs consul in CLIENT mode. Bundles consul::install + consul::configure
# and locks server=false at the role layer so a per-node attribute can't
# accidentally flip a client into a server.
#
# Per-node roles still need to set consul.config.node_name + bind_addr.
# Per-cluster shared attrs (retry_join, datacenter overrides) belong in
# the wrapping role (e.g. role[oracle_node] for the oracle fleet).
# -------------------------------------------------------------------------------

name 'consul_client'
description 'Installs + configures Consul in client mode'

run_list(
  'recipe[consul::install]',
  'recipe[consul::configure]'
)

override_attributes(
  consul: {
    config: {
      server: false,
    },
  }
)
