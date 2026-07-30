# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nomad
# Recipe:: configure
#
# Drops /etc/nomad.d/nomad.hcl + the nomad.service systemd unit, then
# enables and starts the agent. consul_token is fetched lazily via
# munchbox_lib's vault_fetch helper -- lazy{} defers to converge phase
# so it runs AFTER vault_agent::configure has gated on
# /run/vault-agent/token (per feedback_vault_fetch_lazy memory).
# -------------------------------------------------------------------------------

# --- Configure nomad as server, client, or both ---
nomad_configure 'nomad' do
  node_name                       node[cookbook]['config']['node_name']
  bind_addr                       node[cookbook]['config']['bind_addr']
  advertise_ip                    node[cookbook]['config']['advertise_ip']
  advertise_http_port             node[cookbook]['config']['advertise_http_port']
  advertise_rpc_port              node[cookbook]['config']['advertise_rpc_port']
  advertise_serf_port             node[cookbook]['config']['advertise_serf_port']
  datacenter                      node[cookbook]['config']['datacenter']
  region                          node[cookbook]['config']['region']
  log_level                       node[cookbook]['config']['log_level']
  server_enabled                  node[cookbook]['config']['server_enabled']
  bootstrap_expect                node[cookbook]['config']['bootstrap_expect']
  server_join                     node[cookbook]['config']['server_join']
  client_enabled                  node[cookbook]['config']['client_enabled']
  template_use_client_consul_token node[cookbook]['config']['template_use_client_consul_token']
  servers                         node[cookbook]['config']['servers']
  node_pool                       node[cookbook]['config']['node_pool']
  node_class                      node[cookbook]['config']['node_class']
  client_meta                     node[cookbook]['config']['client_meta'].to_hash
  stale_paths                     node[cookbook]['config']['stale_paths'].to_a
  network_interface               node[cookbook]['config']['network_interface']
  gc_disk_usage_threshold         node[cookbook]['config']['gc_disk_usage_threshold']
  gc_inode_usage_threshold        node[cookbook]['config']['gc_inode_usage_threshold']
  consul_enabled                  node[cookbook]['config']['consul_enabled']
  consul_address                  node[cookbook]['config']['consul_address']
  consul_datacenter               node[cookbook]['config']['consul_datacenter']
  consul_ssl                      node[cookbook]['config']['consul_ssl']
  consul_ca_file                  node[cookbook]['config']['consul_ca_file']
  consul_cert_file                node[cookbook]['config']['consul_cert_file']
  consul_key_file                 node[cookbook]['config']['consul_key_file']
  # --- Lazy: vault_fetch runs at converge time in the resource context. Skipped when consul integration is disabled. ---
  consul_token(lazy { node[cookbook]['config']['consul_enabled'] ? vault_fetch('secret/data/consul/nomad-client-token', 'token') : nil })
  vault_enabled                   node[cookbook]['config']['vault_enabled']
  vault_address                   node[cookbook]['config']['vault_address']
  vault_ca_file                   node[cookbook]['config']['vault_ca_file']
  vault_default_identity_aud      node[cookbook]['config']['vault_default_identity_aud']
  vault_default_identity_ttl      node[cookbook]['config']['vault_default_identity_ttl']
  acl_enabled                     node[cookbook]['config']['acl_enabled']
  tls_http                        node[cookbook]['config']['tls_http']
  tls_rpc                         node[cookbook]['config']['tls_rpc']
  tls_ca_file                     node[cookbook]['config']['tls_ca_file']
  tls_cert_file                   node[cookbook]['config']['tls_cert_file']
  tls_key_file                    node[cookbook]['config']['tls_key_file']
  tls_verify_server_hostname      node[cookbook]['config']['tls_verify_server_hostname']
  tls_verify_https_client         node[cookbook]['config']['tls_verify_https_client']
  docker_allow_privileged         node[cookbook]['config']['docker_allow_privileged']
  docker_allow_caps               node[cookbook]['config']['docker_allow_caps']
  docker_volumes_enabled          node[cookbook]['config']['docker_volumes_enabled']
  docker_gc_image                 node[cookbook]['config']['docker_gc_image']
  docker_gc_image_delay           node[cookbook]['config']['docker_gc_image_delay']
  docker_gc_container             node[cookbook]['config']['docker_gc_container']
  docker_gc_dangling_period       node[cookbook]['config']['docker_gc_dangling_period']
  docker_gc_dangling_grace        node[cookbook]['config']['docker_gc_dangling_grace']
  telemetry_prometheus_metrics    node[cookbook]['config']['telemetry_prometheus_metrics']
  telemetry_disable_hostname      node[cookbook]['config']['telemetry_disable_hostname']
  telemetry_publish_alloc_metrics node[cookbook]['config']['telemetry_publish_alloc_metrics']
  telemetry_publish_node_metrics  node[cookbook]['config']['telemetry_publish_node_metrics']
  bin_path                        node[cookbook]['install']['bin_path']
  config_dir                      node[cookbook]['install']['config_dir']
  data_dir                        node[cookbook]['install']['data_dir']
  user                            node[cookbook]['install']['user']
  group                           node[cookbook]['install']['group']
end
