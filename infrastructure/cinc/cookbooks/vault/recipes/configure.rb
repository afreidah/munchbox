# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault
# Recipe:: configure
#
# Drops vault.hcl + the vault.service systemd unit via vault_configure
# resource. Does NOT restart vault on config change by default (shamir-
# sealed; restart = manual unseal x3). consul_storage_token is fetched
# lazily so the recipe defers Vault I/O until converge phase.
# -------------------------------------------------------------------------------

cfg   = node[cookbook]['config']
paths = node[cookbook]['vault_paths']

vault_configure 'vault' do
  node_name      cfg['node_name'] || node.name
  advertise_ip   cfg['advertise_ip']
  cluster_name   cfg['cluster_name']
  log_level      cfg['log_level']
  ui_enabled     cfg['ui_enabled']
  disable_mlock  cfg['disable_mlock']

  listener_address       cfg['listener_address']
  listener_tls_disable   cfg['listener_tls_disable']
  listener_tls_cert_file cfg['listener_tls_cert_file']
  listener_tls_key_file  cfg['listener_tls_key_file']

  api_scheme   cfg['api_scheme']
  api_port     cfg['api_port']
  cluster_port cfg['cluster_port']

  storage_address       cfg['storage_address']
  storage_scheme        cfg['storage_scheme']
  storage_path          cfg['storage_path']
  storage_tls_ca_file   cfg['storage_tls_ca_file']
  storage_tls_cert_file cfg['storage_tls_cert_file']
  storage_tls_key_file  cfg['storage_tls_key_file']
  # --- Lazy: vault_fetch runs at converge time in the resource context. Vault servers chicken-and-egg via the local vault (they ARE the vault, and they're already running). ---
  consul_storage_token(lazy { vault_fetch(paths['consul_storage_token']['path'], paths['consul_storage_token']['field']) })

  service_registration_enabled cfg['service_registration_enabled']

  telemetry_disable_hostname          cfg['telemetry_disable_hostname']
  telemetry_prometheus_retention_time cfg['telemetry_prometheus_retention_time']
  telemetry_usage_gauge_period        cfg['telemetry_usage_gauge_period']
  telemetry_enable_hostname_label     cfg['telemetry_enable_hostname_label']

  bin_path   node[cookbook]['install']['bin_path']
  config_dir node[cookbook]['install']['config_dir']
  user       node[cookbook]['install']['user']
  group      node[cookbook]['install']['group']

  restart_on_change cfg['restart_on_change']
  stale_paths       cfg['stale_paths'].to_a
end
