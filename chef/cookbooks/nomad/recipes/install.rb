# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: nomad
# Recipe:: install
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Downloads and installs the Nomad binary, sets up configuration, and enables the service.
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Include Firewall Recipe and Helpers
# --------------------------------------------------------------------

include_recipe 'nomad::firewall'
Chef::DSL::Recipe.include(Nomad::Helpers)

# --------------------------------------------------------------------
# Determine Architecture for Download
# --------------------------------------------------------------------

arch = node['kernel']['machine']

platform_arch = case arch
                when 'x86_64', 'amd64'
                  'amd64'
                when 'aarch64'
                  'arm64'
                when 'armv7l', 'armv6l', 'armv8l', 'arm'
                  'arm'
                else
                  arch
                end

# --------------------------------------------------------------------
# Create Nomad Config and Data Directories
# --------------------------------------------------------------------

[
  node['nomad']['config_dir'],
  node['nomad']['data_dir'],
].each do |dir|
  directory dir do
    owner node['nomad']['user']
    group node['nomad']['group']
    mode  '0755'
    action :create
  end
end

# --------------------------------------------------------------------
# Download and Extract Nomad Binary (fixed paths + unzip dependency)
# --------------------------------------------------------------------

package 'unzip' # ensure unzip exists

nomad_download = "nomad_#{node['nomad']['version']}_linux_#{platform_arch}.zip"
download_url   = "https://releases.hashicorp.com/nomad/#{node['nomad']['version']}/#{nomad_download}"
cache_file     = ::File.join(Chef::Config[:file_cache_path], nomad_download)

remote_file cache_file do
  source download_url
  mode '0644'
  # checksum '...'  # ← strongly recommended: add official SHA256 for the exact version
  action :create
  notifies :run, 'bash[install-nomad]', :immediately
end

bash 'install-nomad' do
  code <<-EOH
    unzip -o #{cache_file} -d /tmp
    install -m 0755 /tmp/nomad #{node['nomad']['bin_path']}/nomad
  EOH
  not_if { ::File.exist?("#{node['nomad']['bin_path']}/nomad") && nomad_version == "v#{node['nomad']['version']}" }
  notifies :restart, 'service[nomad]', :delayed
  action :nothing
end

# --------------------------------------------------------------------
# Create Nomad Config File
# --------------------------------------------------------------------

vault_item = encrypted_data_bag_item('vault', 'vault_token')

template '/etc/nomad.d/server.hcl' do
  source 'config.hcl.erb'
  variables(
    retry_join: node['nomad']['server']['servers'].map { |h| "#{h}:4648" },
    token: vault_item['token'] # ← make name match template
  )
  sensitive true
  mode '0640'
  owner node['nomad']['user']
  group node['nomad']['group']
  notifies :restart, 'service[nomad]', :delayed
end

directory node['nomad']['config_dir'] do
  owner node['nomad']['user']
  group node['nomad']['group']
  mode  '0750' # tighter
end

directory node['nomad']['data_dir'] do
  owner node['nomad']['user']
  group node['nomad']['group']
  mode  '0755'
end

# --------------------------------------------------------------------
# Render systemd Unit and Reload Daemon
# --------------------------------------------------------------------

execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

template '/etc/systemd/system/nomad.service' do
  source 'nomad.service.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    config_dir: node['nomad']['config_dir'],
    data_dir: node['nomad']['data_dir'],
    service_user: node['nomad']['user'],
    service_group: node['nomad']['group']
  )
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

# --------------------------------------------------------------------
# Create Host Volume Mount Directories
# --------------------------------------------------------------------

node['nomad']['client']['host_volumes'].each do |volume|
  directory volume['path'] do
    owner node['nomad']['user']
    group node['nomad']['group']
    mode '0777'
    recursive true
    action :create
  end
end

# --------------------------------------------------------------------
# Enable and Start Nomad Service
# --------------------------------------------------------------------

service 'nomad' do
  provider Chef::Provider::Service::Systemd
  action [:enable, :start]
  subscribes :restart, 'template[/etc/systemd/system/nomad.service]', :immediately
end
