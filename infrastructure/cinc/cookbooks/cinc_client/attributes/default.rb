# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Attributes:: default
#
# Defaults for the cinc_client cookbook. Every entry is keyed under the
# cookbook's namespace via `node[cookbook]`, so renaming the cookbook is
# a one-line change in metadata.rb.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# cinc package
#
# Fetched as a .deb directly from packages.cinc.sh (cinc-project's
# packagecloud apt repo serves 404 for every codename). Pin a known-good
# version so client upgrades are deliberate, not silent. Keep this in sync
# with the omnibus `-v` flag in infrastructure/cinc/scripts/bootstrap-cinc-node.sh
# so fresh nodes don't drift from the cookbook pin between bootstrap and
# first converge.
# -------------------------------------------------------------------------------

default[cookbook]['install'] = {
  version: '19.3.14',
  package_name: 'cinc',
  download_base: 'https://packages.cinc.sh/files',
  channel: 'stable',
}

# -------------------------------------------------------------------------------
# Client configuration
#
# `chef_server_url`, `validator_pem`, and `trusted_cert` are the bare
# minimum for first-run registration. `validator_pem` and `trusted_cert`
# default to nil -- the operator must override them (eventually via Vault).
# Without `validator_pem`, the first cinc-client run can't register; the
# cookbook still drops everything else and the node can be hand-bootstrapped.
# -------------------------------------------------------------------------------

default[cookbook]['config'] = {
  chef_server_url: 'https://cinc-server.munchbox.cc/organizations/munchbox',
  node_name: nil,
  log_level: 'info',
  log_location: '/var/log/cinc/client.log',
  validator_client_name: 'munchbox-validator',
  trusted_cert: nil,
  validator_pem: nil,
}

# -------------------------------------------------------------------------------
# Periodic-run timer
#
# Disabled by default so kitchen + first-time provisioning don't try to
# converge against an unreachable / not-yet-trusted server. Production
# nodes flip `timer_enabled` to true after first-run registration is
# verified.
# -------------------------------------------------------------------------------

default[cookbook]['service'] = {
  timer_enabled: false,
  on_calendar: 'hourly',
  # --- Each node picks a random offset within this window so the fleet doesn't thundering-herd cinc-server / Vault every hour ---
  randomized_delay_sec: '30m',
}
