# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Recipe:: configure
#
# Drops /etc/cinc/client.rb, the cinc-server trusted cert under
# /etc/cinc/trusted_certs/, and (if provided) the org validator pem at
# /etc/cinc/validation.pem so the first cinc-client run can register.
# -------------------------------------------------------------------------------

cinc_client_configure 'cinc' do
  chef_server_url       node[cookbook]['config']['chef_server_url']
  node_name             node[cookbook]['config']['node_name']
  log_level             node[cookbook]['config']['log_level']
  log_location          node[cookbook]['config']['log_location']
  validator_client_name node[cookbook]['config']['validator_client_name']
  trusted_cert          node[cookbook]['config']['trusted_cert']
  validator_pem         node[cookbook]['config']['validator_pem']
end
