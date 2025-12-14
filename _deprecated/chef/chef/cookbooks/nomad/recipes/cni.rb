# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Nomad Cookbook - CNI Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs the CNI plugins required for Nomad networking.
# -------------------------------------------------------------------------------

# --- Determine Platform Architecture ---

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

# --- Build CNI Plugin Download URL ---

base_url = "#{node['nomad']['cni']['url']}/cni-plugin-linux"
full_url = "#{base_url}-#{platform_arch}-#{node['nomad']['cni']['version']}.tgz"

# --- Ensure CNI Directory Exists ---

directory node['nomad']['cni']['path'] do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# --- Download and Extract CNI Plugins ---

cni_tgz   = ::File.join(Chef::Config[:file_cache_path], 'cni-plugins.tgz')
cni_bin   = ::File.join(node['nomad']['cni']['path'], 'bridge') # any plugin as sentinel

remote_file cni_tgz do
  source full_url
  mode '0644'
  action :create
  not_if { ::File.exist?(cni_bin) }
  # checksum '...' # recommended
  notifies :extract, "archive_file[#{cni_tgz}]", :immediately
end

archive_file cni_tgz do
  destination node['nomad']['cni']['path']
  overwrite false
  action :nothing
end

# --- Configure Kernel Bridge Settings for CNI Networking ---

template '/etc/sysctl.d/bridge.conf' do
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
