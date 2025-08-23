# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: nomad
# Recipe:: default
# Purpose:: Call install, configure, cluster resources with attributes.
# --------------------------------------------------------------------

include_recipe 'nomad::firewall'

# --- Install package dependencies ---
node['nomad']['packages'].each do |pkg|
  package pkg do
    action :install
  end
end

# === Install Nomad ==================================================
nomad_install 'nomad' do
  version      node['nomad']['version']
  bin_path     node['nomad']['bin_path']
  checksums    node['nomad']['checksums'] # optional but recommended
end

# === Configure Nomad ================================================
vault_item = begin
  encrypted_data_bag_item('vault', 'vault_token')
             rescue StandardError
               {}
end

Chef::Log.warn("DEBUG: node['nomad']['server']['enabled'] = #{node['nomad']['server']['enabled'].inspect}")
nomad_configure 'nomad' do
  config_dir     node['nomad']['config_dir']
  data_dir       node['nomad']['data_dir']
  bind_addr      node['nomad']['bind_addr']
  datacenter     node['nomad']['datacenter']
  server_enabled node['nomad']['server']['enabled']
  client_enabled node['nomad']['client']['enabled']
  retry_join     node['nomad']['server']['servers'].map { |h| "#{h}:4648" }
  telemetry      node['nomad']['telemetry']
  docker         node['nomad']['docker']
  consul_auto    node['nomad']['consul']['auto_join']
  vault({ 'enabled' => node['nomad']['vault']['enabled'],
          'address' => node['nomad']['vault']['address'],
          'token' => vault_item['token'] })
  user           node['nomad']['user']
  group          node['nomad']['group']
  enable_cni     node['nomad']['cni']['enabled']
  cni_version    node['nomad']['cni']['version']
  cni_path       node['nomad']['cni']['path']
  cni_url_base   node['nomad']['cni']['url']
end

# === Cluster bring‑up ===============================================
nomad_cluster 'nomad' do
  bind_addr       node['nomad']['bind_addr']
  wait_for_consul false
  acl_enabled     true
  bootstrap_this  node['nomad']['acl']['bootstrap_this_node']
end

tags = node['nomad']['client_tags']
template '/etc/nomad.d/010-client-tags.hcl' do
  source 'client-tags.hcl.erb'
  owner  'root'
  group  'root'
  mode   '0644'
  variables(tags: tags)
  notifies :restart, 'service[nomad]', :delayed
  only_if { tags && !tags.empty? }
end
