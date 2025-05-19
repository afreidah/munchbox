# frozen_string_literal: true
#
# Cookbook:: nomad
# Recipe:: install
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Downloads and installs the Nomad binary, sets up configuration, and enables the service.
#

# =========================
# Include Firewall Recipe and Helpers
# =========================

include_recipe 'nomad::firewall'
Chef::Recipe.include(Nomad::Helpers)

# =========================
# Determine Architecture for Download
# =========================

arch = node['kernel']['machine']

case arch
when 'x86_64', 'amd64'
  platform_arch = 'amd64'
when 'aarch64'
  platform_arch = 'arm64'
when 'armv7l', 'armv6l', 'armv8l', 'arm'
  platform_arch = 'arm'
else
  platform_arch = arch
end

# =========================
# Download and Extract Nomad Binary
# =========================

remote_file 'nomad.zip' do
  path        '/tmp/nomad.zip'
  source      "https://releases.hashicorp.com/nomad/#{node['nomad']['version']}/nomad_#{node['nomad']['version']}_linux_#{platform_arch}.zip"
  notifies    :run, 'execute[unzip-nomad]', :immediately
  not_if { nomad_version == "v#{node['nomad']['version']}" }
end

execute 'unzip-nomad' do
  command "unzip -o /tmp/nomad.zip -d #{node['nomad']['bin_path']}"
  creates "#{node['nomad']['bin_path']}/nomad"
  action  :nothing
end

# =========================
# Create Nomad Config File
# =========================

template '/etc/nomad.d/server.hcl' do
  source 'config.hcl.erb'
  variables(
    bootstrap_expect: node['nomad']['servers'].size,
    retry_join: node['nomad']['servers'].map { |h| "#{h}:4648" }
  )
  notifies :restart, 'service[nomad]', :delayed
end

# =========================
# Create Nomad Config and Data Directories
# =========================

[
  node['nomad']['config_dir'],
  node['nomad']['data_dir']
].each do |dir|
  directory dir do
    owner node['nomad']['user']
    group node['nomad']['group']
    mode  '0755'
    action :create
  end
end

# =========================
# Render systemd Unit and Reload Daemon
# =========================

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

# =========================
# Create Host Volume Mount Directories
# =========================

node['nomad']['host_volumes'].each do |volume|
  volume.each do |name, config|
    directory config['path'] do
      owner node['nomad']['user']
      group node['nomad']['group']
      mode '0755'
      recursive true
      action :create
    end
  end
end

# =========================
# Enable and Start Nomad Service
# =========================

service 'nomad' do
  provider Chef::Provider::Service::Systemd
  action [:enable, :start]
  subscribes :restart, 'template[/etc/systemd/system/nomad.service]', :immediately
end
