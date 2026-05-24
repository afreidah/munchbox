# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault_cert_manager
# Recipe:: install
#
# apt install vault-cert-manager from the munchbox aptly repo. The repo
# itself is registered by munchbox_base::apt_repo earlier in the run_list.
# -------------------------------------------------------------------------------

install = node[cookbook]['install']

# --- Wait for apt lock; earlier recipes may still be holding it. ---
munchbox_base_apt_lock_wait 'vault_cert_manager_install'

apt_package install['package_name'] do
  action :upgrade
  notifies :restart, 'service[vault-cert-manager]', :delayed
end

directory install['config_dir'] do
  owner install['user']
  group install['group']
  mode  '0755'
end

# --- Stub for notifications; configure recipe upgrades to :enable+:start. ---
service 'vault-cert-manager' do
  action :nothing
end
