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
# Pulled from the cinc-project packagecloud apt repo. Pin a known-good
# version so client upgrades are deliberate, not silent.
# -------------------------------------------------------------------------------

default[cookbook]['install'] = {
  'version' => '19.2.12',
  'package_name' => 'cinc',
  'apt_repo_uri' => 'https://packagecloud.io/cinc-project/stable/debian/',
  'apt_repo_key' => 'https://packagecloud.io/cinc-project/stable/gpgkey',
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
  'chef_server_url' => 'https://cinc-server.munchbox.cc/organizations/munchbox',
  'node_name' => nil,
  'log_level' => 'info',
  'log_location' => '/var/log/cinc/client.log',
  'validator_client_name' => 'munchbox-validator',
  'trusted_cert' => nil,
  'validator_pem' => nil,
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
  'timer_enabled' => false,
  'on_calendar' => 'hourly',
}
