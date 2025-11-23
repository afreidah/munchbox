# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  install.rb — Installs Consul using official HashiCorp binaries or packages
#
#  This recipe installs Consul, creates required users, directories, and
#  systemd service units, and ensures the service is enabled and started.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
#  Include Firewall Recipe
# ------------------------------------------------------------------------------

include_recipe 'consul::firewall'

# --------------------------------------------------------------------
# Load agent token from encrypted data bag (chef-solo)
# --------------------------------------------------------------------
begin
  agent_item = Chef::EncryptedDataBagItem.load('consul', 'agent')
  node.default['consul']['acl'] ||= {}
  node.default['consul']['acl']['enabled'] = true
  node.default['consul']['acl']['tokens'] ||= {}
  node.default['consul']['acl']['tokens']['agent'] = agent_item['token']
rescue => e
  Chef::Log.warn("Consul agent token not loaded: #{e}")
end

# ------------------------------------------------------------------------------
#  Install Consul (binary or package, user/group, directories)
# ------------------------------------------------------------------------------

consul_install 'consul' do
  version        node['consul']['version']
  install_method node['consul']['install_method']
  user           node['consul']['user']
  group          node['consul']['group']
  data_dir       node['consul']['data_dir']
  config_dir     node['consul']['config_dir']
  install_dir    node['consul']['install_dir']
  checksum       node['consul']['checksum'] if node['consul'].key?('checksum')
end

# ------------------------------------------------------------------------------
#  Render Consul HCL Config
# ------------------------------------------------------------------------------

consul_config 'consul' do
  config_dir  node['consul']['config_dir']
  install_dir node['consul']['install_dir']
  user        node['consul']['user']
  group       node['consul']['group']
  notifies    :create, 'consul_service[consul]', :immediately
  notifies    :restart, 'service[consul]', :delayed
end

# ------------------------------------------------------------------------------
#  Render Consul systemd Unit and Manage Service
# ------------------------------------------------------------------------------

consul_service 'consul' do
  user        node['consul']['user']
  group       node['consul']['group']
  data_dir    node['consul']['data_dir']
  config_dir  node['consul']['config_dir']
  install_dir node['consul']['install_dir']
  action      :create
end

service 'consul' do
  action [:enable, :start]
end
