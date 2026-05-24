# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: cinc_client
#
# Adds cinc-client to a node so it's a chef-managed loop participant:
# installs the package, drops config (client.rb + trusted cert + first-run
# validator), installs the systemd timer with periodic runs enabled.
#
# Any role/node that wants the node to be chef-managed includes
# role[cinc_client]; no need to list the individual recipes anywhere
# else.
# -------------------------------------------------------------------------------

name 'cinc_client'
description 'Installs + configures cinc-client and enables the periodic timer'

run_list(
  'recipe[cinc_client::install]',
  'recipe[cinc_client::configure]',
  'recipe[cinc_client::data_bag_secret]',
  'recipe[cinc_client::service]'
)

override_attributes(
  cinc_client: {
    service: {
      timer_enabled: true,
    },
  }
)
