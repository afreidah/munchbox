# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Recipe:: install
#
# Registers the cinc-project apt repo and installs the cinc package at
# the pinned version.
# -------------------------------------------------------------------------------

cinc_client_install 'cinc' do
  version      node[cookbook]['install']['version']
  package_name node[cookbook]['install']['package_name']
  apt_repo_uri node[cookbook]['install']['apt_repo_uri']
  apt_repo_key node[cookbook]['install']['apt_repo_key']
end
