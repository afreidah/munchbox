# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: cinc_server_host
#
# The cinc/chef server itself. Composes role[base] (OS baseline) +
# cinc_server::* (the server itself) + role[cinc_client] (so the host is
# chef-managed like every other node). Server-managed-by-itself loop.
# -------------------------------------------------------------------------------

name 'cinc_server_host'
description 'The cinc/chef server itself; runs base + cinc_server::* + cinc_client'

run_list(
  'role[base]',
  'recipe[cinc_server::install]',
  'recipe[cinc_server::configure]',
  'recipe[cinc_server::bootstrap]',
  'role[cinc_client]'
)
