# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Recipe:: configure
#
# Templates /etc/opscode/chef-server.rb and runs `chef-server-ctl
# reconfigure` whenever the config changes.
# -------------------------------------------------------------------------------

cinc_server_configure 'cinc-server' do
  api_fqdn node[cookbook]['config']['api_fqdn']
  settings node[cookbook]['config']['settings'].to_hash
end
