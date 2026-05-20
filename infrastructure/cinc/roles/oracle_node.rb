# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: oracle_node
#
# Oracle Cloud free-tier nodes. Composes role[base] (OS baseline) +
# role[cinc_client] (chef-managed loop). WireGuard and other
# oracle-specific concerns come in later as their cookbooks land.
# -------------------------------------------------------------------------------

name 'oracle_node'
description 'Oracle Cloud free-tier node; runs base + cinc_client'

run_list(
  'role[base]',
  'role[cinc_client]',
  'recipe[cinc_client::disable_apt_daily]'
)
