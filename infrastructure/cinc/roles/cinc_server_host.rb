# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: cinc_server_host
#
# The cinc/chef server itself. Composes role[base] (OS baseline) +
# cinc_server::* (the server itself) + role[cinc_client] (so the host is
# chef-managed like every other node). Server-managed-by-itself loop.
# Also runs a local consul agent + registers itself in the catalog so
# cinc-server.service.consul resolves cluster-wide.
# -------------------------------------------------------------------------------

name 'cinc_server_host'
description 'The cinc/chef server itself; runs base + cinc_server::* + cinc_client + consul-client + self-register'

run_list(
  'role[base]',
  'role[cinc_client]',
  'role[vault_agent]',
  'recipe[munchbox_base::vault_pki_trust]',
  'role[vault_cert_manager]',
  'role[consul_client]',
  'recipe[cinc_server::install]',
  'recipe[cinc_server::configure]',
  'recipe[cinc_server::bootstrap]',
  'recipe[cinc_server::register]',
)
