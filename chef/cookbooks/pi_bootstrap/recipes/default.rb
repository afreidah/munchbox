# frozen_string_literal: true
#
# Cookbook:: pi_bootstrap
# Recipe:: default
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Bootstraps a Raspberry Pi with hostname, package installation, and Docker service.
#

# =========================
# Set Variables
# =========================
host = "#{node['pi_bootstrap']['hostname_prefix']}-#{node['ipaddress'].split('.').last}"

# hopefully this will be the last time I need to do this
## =========================
## Reload Ohai Network Attributes
## =========================
#
#ohai 'reload network attributes' do
#  plugin 'network'
#  action :nothing
#end
#
## Force Ohai network reload at compile time so node['ipaddress'] is set
#ruby_block 'reload Ohai network plugin at compile-time' do
#  block do
#    resources(ohai: 'reload network attributes').run_action(:reload)
#  end
#end

# =========================
# Log Detected IP Address
# =========================

ruby_block 'log my ipaddress' do
  block do
    ip = node['ipaddress']
    Chef::Log.info("My IP address is #{ip}")
  end
end

# =========================
# Set Hostname Based on IP Address
# =========================

template '/etc/hostname' do
  source 'hostname.erb'
  variables(hostname: host)
  notifies :run, 'execute[hostnamectl-set]', :immediately
end

execute 'hostnamectl-set' do
  command lazy { "hostnamectl set-hostname #{host}" }
  action :nothing
end

# =========================
# Update /etc/hosts with New Hostname
# =========================

ruby_block 'update_etc_hosts' do
  block do
    hosts = ::File.read('/etc/hosts').lines.reject { |l| l =~ /127\.0\.1\.1/ }
    hosts << "127.0.1.1   #{host}\n"
    ::File.write('/etc/hosts', hosts.join)
  end
  only_if { ::File.exist?('/etc/hosts') }
end

# =========================
# Install Required Packages
# =========================

package node['pi_bootstrap']['packages'] do
  action :install
end

# =========================
# Enable and Start Docker Service
# =========================

service 'docker' do
  action [:enable, :start]
  only_if { systemd? }
end
