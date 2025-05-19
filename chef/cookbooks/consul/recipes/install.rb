# frozen_string_literal: true
#
# Cookbook:: consul
# Recipe:: install
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Installs Consul via HashiCorp’s official binary archive or package manager,
# creates necessary users, directories, and systemd service.
#

# =========================
# Include Firewall Recipe
# =========================

include_recipe 'consul::firewall'

# =========================
# Set Install Variables
# =========================

consul_version        = node['consul']['version']
consul_install_method = node['consul']['install_method']
consul_user           = node['consul']['user']
consul_group          = node['consul']['group']
consul_data_dir       = node['consul']['data_dir']
consul_config_dir     = node['consul']['config_dir']
consul_install_dir    = node['consul']['install_dir']
consul_binary         = ::File.join(consul_install_dir, 'consul')

# =========================
# Install Consul
# =========================

case consul_install_method
when 'binary'
  archive_url  = "https://releases.hashicorp.com/consul/#{consul_version}/consul_#{consul_version}_linux_arm64.zip"
  archive_path = ::File.join(Chef::Config[:file_cache_path], "consul_#{consul_version}.zip")

  remote_file archive_path do
    source archive_url
    checksum node['consul']['checksum'] if node['consul'].key?('checksum')
    action :create
    not_if { ::File.exist?(consul_binary) && `#{consul_binary} version`.include?(consul_version) }
  end

  directory consul_install_dir do
    mode '0755'
    recursive true
  end

  execute 'unzip_consul' do
    command "unzip -o #{archive_path} -d #{consul_install_dir}"
    not_if { ::File.exist?(consul_binary) && `#{consul_binary} version`.include?(consul_version) }
  end

  file consul_binary do
    mode '0755'
  end

when 'package'
  package 'consul' do
    version consul_version
    action :install
    not_if { ::File.exist?(consul_binary) && `#{consul_binary} version`.include?(consul_version) }
  end

else
  Chef::Log.error("Unknown consul install_method '#{consul_install_method}'")
end

# =========================
# Create Consul User & Group
# =========================

group consul_group do
  system true
end

user consul_user do
  system true
  gid consul_group
  home consul_data_dir
  shell '/bin/false'
end

# =========================
# Create Consul Directories
# =========================

[consul_data_dir, consul_config_dir].each do |dir|
  directory dir do
    owner consul_user
    group consul_group
    mode '0750'
    recursive true
  end
end

# =========================
# Reload systemd When Unit File Changes
# =========================

execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# =========================
# Render Consul systemd Unit
# =========================

template '/etc/systemd/system/consul.service' do
  source 'consul.service.erb'
  owner consul_user
  group consul_group
  mode '0644'
  variables(
    install_dir: consul_install_dir,
    config_dir: consul_config_dir,
    data_dir: consul_data_dir,
    service_user: consul_user,
    service_group: consul_group
  )
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

# =========================
# Enable & Start Consul Service
# =========================

service 'consul' do
  provider Chef::Provider::Service::Systemd
  action [:enable, :start]
  subscribes :restart, 'template[/etc/systemd/system/consul.service]', :immediately
end
