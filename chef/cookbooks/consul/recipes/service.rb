# frozen_string_literal: true
#
# Cookbook:: consul
# Recipe:: service
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Configures Consul service directories and renders the main server configuration.
#

include_recipe 'consul::install'

# =========================
# Ensure Consul Config Directory Ownership
# =========================

directory node['consul']['config_dir'] do
  owner  node['consul']['service_user']
  group  node['consul']['service_group']
  mode   '0755'
end

# =========================
# Render Consul Server JSON Configuration
# =========================

template ::File.join(node['consul']['config_dir'], 'server.json') do
  source 'consul-config.json.erb'
  owner  'root'
  group  'root'
  mode   '0644'
  variables(
    data_dir:   node['consul']['data_dir'],
    bind_addr:  node['consul']['bind_addr'],
    retry_join: node['consul']['servers']
  )
  notifies :restart, 'service[consul]', :immediately
end
