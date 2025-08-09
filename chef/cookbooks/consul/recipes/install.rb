# frozen_string_literal: true
#
# --------------------------------------------------------------------
# Cookbook:: consul
# Recipe:: install
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Installs Consul via HashiCorp’s official binary archive or package manager,
# creates necessary users, directories, and systemd service.
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Create Consul User & Group
# --------------------------------------------------------------------

group consul_group do
  system true
end

# user consul_user do
#   system true
#   gid consul_group
#   home consul_data_dir
#   shell '/bin/false'
# end

# --------------------------------------------------------------------
# Create Consul Directories
# --------------------------------------------------------------------

[consul_data_dir, consul_config_dir].each do |dir|
  directory dir do
    owner consul_user
    group consul_group
    mode '0750'
    recursive true
  end
end

# --------------------------------------------------------------------
# Reload systemd When Unit File Changes
# --------------------------------------------------------------------

execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# --------------------------------------------------------------------
# Render Consul systemd Unit
# --------------------------------------------------------------------

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

# --------------------------------------------------------------------
# Enable & Start Consul Service
# --------------------------------------------------------------------

service 'consul' do
  provider Chef::Provider::Service::Systemd
  action [:enable, :start]
  subscribes :restart, 'template[/etc/systemd/system/consul.service]', :immediately
end
