# frozen_string_literal: true

# -------------------------------------------------------------------------------
# OpenBao Cookbook - Default Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs, configures, and clusters OpenBao (bare-metal). Installs packages,
# TLS certs from data bag, writes config, and handles init/unseal/join.
# -------------------------------------------------------------------------------

require 'json'

# --- Bootstrap/Firewall ---
include_recipe 'openbao::firewall'

# --- Package and Environment Setup ---
cookbook_file '/etc/profile.d/bao_env.sh' do
  owner  'root'
  group  'root'
  mode   '0644'
  source 'bao_env.sh'
end

node[cookbook_name]['install_packages'].each do |pkg|
  apt_package pkg do
    action :install
  end
end

# --- Variables ---
service_name  = (node[cookbook_name]['service_name'] rescue nil) || 'openbao'
hostname_val  = node['fqdn'] || node['hostname']

config_path   = node[cookbook_name]['config_path']          # e.g., /etc/openbao/openbao.hcl
storage_path  = node[cookbook_name]['storage']['path']      # e.g., /opt/openbao/data

tls_dir       = node[cookbook_name]['ssl']['target_path']   # e.g., /etc/openbao/tls
tls_cert_path = ::File.join(tls_dir, 'bao.crt')
tls_key_path  = ::File.join(tls_dir, 'bao.key')
tls_ca_path   = ::File.join(tls_dir, 'ca.crt')

api_addr      = "https://#{hostname_val}:8200"

# --- Install OpenBao ---
openbao_install service_name do
  action  :install
  version node[cookbook_name]['openbao_version']
end

# --- TLS Certificates (from data bag) ---
directory tls_dir do
  owner node[cookbook_name]['user']
  group node[cookbook_name]['group']
  mode  '0750'
  recursive true
end

certificate_installer 'install openbao certs' do
  owner       node[cookbook_name]['user']
  group       node[cookbook_name]['group']
  databag     node[cookbook_name]['ssl']['data_bag']         # e.g., 'infra_certs'
  item        node[cookbook_name]['ssl']['data_bag_item']    # e.g., 'ssl'
  section     node[cookbook_name]['ssl']['data_bag_section'] # e.g., 'openbao'
  target_path node[cookbook_name]['ssl']['target_path']      # e.g., '/etc/openbao/tls'
  sensitive   true
  action      :install
end

# --- Configure OpenBao (writes openbao.hcl from template) ---
openbao_configure "configure #{service_name}" do
  service_user    node[cookbook_name]['user']
  service_group   node[cookbook_name]['group']
  config_path     config_path
  template_source 'openbao.hcl.erb'

  # --- Template variables ---
  hostname     hostname_val
  storage_path storage_path
  node_id      lazy { node['hostname'] }

  # --- TLS material written above ---
  tls_cert     tls_cert_path
  tls_key      tls_key_path
  tls_ca       tls_ca_path

  action :create
end

# --- Service (ensure running before cluster ops) ---
service service_name do
  action [:enable, :start]
end

# --- Cluster: INIT + UNSEAL + JOIN ---
openbao_cluster "#{service_name}_cluster" do
  service_name service_name
  api_addr     api_addr
  tls_cert     tls_cert_path
  tls_key      tls_key_path
  tls_ca       tls_ca_path
  # Optional:
  # unseal_keys node['openbao']['cluster']['unseal_keys']
  # join_addrs  node['openbao']['cluster']['join_addrs']
  action [:init, :unseal, :join]
end

init_json   = node.dig(cookbook_name, 'cluster', 'init_sentinel') || '/var/lib/openbao/init.json'
vault_addr  = "https://#{node['fqdn'] || node['hostname']}:8200"
cacert_path = node[cookbook_name]['ssl']['target_path'] + '/ca.crt'

directory '/var/log/openbao' do
  owner 'openbao'
  group 'openbao'
  mode  '0750'
end

execute 'openbao-audit-enable' do
  command 'bao audit enable file file_path=/var/log/openbao/audit.log'
  environment lazy {
    token =
      if ::File.exist?(init_json)
        JSON.parse(::File.read(init_json))['root_token']
      else
        # fallback: use a provided bootstrap/admin token via attribute or current env
        node.dig(cookbook_name, 'bootstrap_token') || ENV['VAULT_TOKEN']
      end

    {
      'VAULT_ADDR'   => vault_addr,
      'VAULT_CACERT' => cacert_path,
      'VAULT_TOKEN'  => token
    }
  }
  not_if 'bao audit list | awk \'{print $1}\' | grep -qx "file/"', environment: lazy {
    token =
      if ::File.exist?(init_json)
        JSON.parse(::File.read(init_json))['root_token']
      else
        node.dig(cookbook_name, 'bootstrap_token') || ENV['VAULT_TOKEN']
      end

    {
      'VAULT_ADDR'   => vault_addr,
      'VAULT_CACERT' => cacert_path,
      'VAULT_TOKEN'  => token
    }
  }
  sensitive true
end
