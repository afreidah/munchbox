# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault_cert_manager
# Recipe:: configure
#
# Drops the secret_id file (vault_fetched), config.yaml, systemd
# Restart=always drop-in, and the consul service-registration JSON.
# Enables + starts vault-cert-manager.service.
#
# AppRole creds (role_id + secret_id) are fetched lazily via munchbox_lib's
# vault_fetch helper so they evaluate at converge time -- after vault_agent
# has gated on /run/vault-agent/token (per feedback_vault_fetch_lazy).
# -------------------------------------------------------------------------------

install      = node[cookbook]['install']
config       = node[cookbook]['config']
vault_paths  = node[cookbook]['vault_paths']
# --- Pre-resolve here; `cookbook` is shadowed inside template/file blocks. ---
certificates = node[cookbook]['certificates'].to_a.map { |c| c.respond_to?(:to_hash) ? c.to_hash : c }
service_file = node[cookbook]['consul_service_file']

# --- secret_id file: sensitive, 0600, owned by the daemon's user; restart on change ---
file "#{install['config_dir']}/secret_id" do
  content   lazy { vault_fetch(vault_paths['secret_id']['path'], vault_paths['secret_id']['field']) }
  owner     install['user']
  group     install['group']
  mode      '0600'
  sensitive true
  notifies :restart, 'service[vault-cert-manager]', :delayed
end

# --- Main config: vault address, AppRole config (role_id fetched lazily), prometheus, logging, certificates list. ---
template "#{install['config_dir']}/config.yaml" do
  source 'config.yaml.erb'
  owner  install['user']
  group  install['group']
  mode   '0640'
  sensitive true
  variables(
    vault_address: config['vault_address'],
    pki_mount: config['pki_mount'],
    skip_verify: config['skip_verify'],
    approle_mount: config['approle_mount'],
    secret_id_file: "#{install['config_dir']}/secret_id",
    metrics_port: config['metrics_port'],
    metrics_refresh: config['metrics_refresh'],
    log_level: config['log_level'],
    log_format: config['log_format'],
    certificates:,
    role_id: lazy { vault_fetch(vault_paths['role_id']['path'], vault_paths['role_id']['field']) }
  )
  notifies :restart, 'service[vault-cert-manager]', :delayed
end

# --- Systemd drop-in: Restart=always so the daemon recovers from transient Vault outages. ---
directory '/etc/systemd/system/vault-cert-manager.service.d' do
  owner 'root'
  group 'root'
  mode  '0755'
end

file '/etc/systemd/system/vault-cert-manager.service.d/restart.conf' do
  content <<~CONF
    # Managed by chef (vault_cert_manager::configure) -- do not edit by hand.
    [Service]
    Restart=always
    RestartSec=15
  CONF
  owner 'root'
  group 'root'
  mode  '0644'
  notifies :run, 'execute[systemctl daemon-reload vault-cert-manager]', :immediately
  notifies :restart, 'service[vault-cert-manager]', :delayed
end

execute 'systemctl daemon-reload vault-cert-manager' do
  command 'systemctl daemon-reload'
  action :nothing
end

# --- Consul service registration for the prometheus scrape. Gated by consul user existence so chef can run on a greenfield node where consul cookbook hasn't installed yet (vault_cert_manager comes BEFORE consul_client in the run_list so certs are issued before consul tries to start). Next converge -- after consul::install creates the user -- writes this file. ---
template service_file do
  source 'consul-service.json.erb'
  owner  'consul'
  group  'consul'
  mode   '0640'
  variables(
    metrics_port: config['metrics_port']
  )
  notifies :reload, 'service[consul]', :delayed
  only_if { ::Etc.getpwnam('consul') rescue false }
end

service 'vault-cert-manager' do
  action %i(enable start)
end

# --- Declared so the consul-service template can notify a reload; consul itself is owned by the consul cookbook. ---
service 'consul' do
  action :nothing
end
