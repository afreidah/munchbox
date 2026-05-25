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

# --- Ensure every cert/registration owner exists before the daemon chowns ---
pairs  = node[cookbook]['ensure_users'].map { |e| [e['user'], e['group']] }
pairs += node[cookbook]['certificates'].map { |c| [c['owner'], c['group']] }
pairs.uniq.each do |user, group|
  next if user.nil? || group.nil?

  group group do
    system true
  end

  user user do
    group group
    system true
    shell '/bin/false'
    manage_home false
  end
end

# --- Stub for notifications; configure recipe upgrades to :enable+:start. ---
service 'vault-cert-manager' do
  action :nothing
end
