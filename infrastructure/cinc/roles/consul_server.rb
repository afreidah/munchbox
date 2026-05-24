# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: consul_server
#
# Runs consul in SERVER mode. Bundles consul::install + consul::configure
# and locks server=true at the role layer (per-node attrs can't downgrade
# a server to a client by accident).
#
# bootstrap_expect is pinned to the current munchbox cluster size (3:
# goren, stabler, nomad-server-03). If a second consul cluster ever
# appears, factor this back out into per-cluster roles.
#
# Per-node roles still need to set consul.config.node_name + bind_addr.
# Per-cluster shared attrs (retry_join with all server LAN IPs) belong
# in the wrapping role for that cluster.
# -------------------------------------------------------------------------------

name 'consul_server'
description 'Installs + configures Consul in server mode (3-node munchbox cluster)'

run_list(
  'recipe[consul::install]',
  'recipe[consul::configure]'
)

override_attributes(
  consul: {
    config: {
      server: true,
      bootstrap_expect: 3,
    },
  }
)
