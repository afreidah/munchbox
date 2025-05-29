# frozen_string_literal: true
#
# Cookbook:: nomad
# Recipe:: cni
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# # Installs the CNI plugins required for Nomad networking.

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

base_url = "#{node['nomad']['cni']['url']}/cni-plugin-linux"
full_url = "#{base_url}-#{platform_arch}-#{node['nomad']['cni']['version']}.tgz"

directory node['nomad']['cni']['path'] do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

remote_file '/tmp/cni-plugins.tgz' do
  source full_url
  mode '0644'
  notifies :extract, 'archive_file[/tmp/cni-plugins.tgz]', :immediately
end

archive_file '/tmp/cni-plugins.tgz' do
  destination node['nomad']['cni']['path']
  overwrite true
  action :nothing
end

template //etc/sysctl.d/bridge.conf do
  source 'bridge.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :run, 'execute[apply-sysctl]', :immediately
end

execute 'apply-sysctl' do
  command 'sysctl --system'
  action :nothing
end
