# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: consul
# Recipe:: configure
#
# Drops /etc/consul.d/consul.hcl + the consul.service systemd unit, then
# enables and starts the agent. ACL agent token is fetched at converge
# time via munchbox_lib's vault_fetch helper -- wrapped in lazy {} so it
# defers to converge phase, AFTER vault_agent::configure has started
# vault-agent.service + gated on /run/vault-agent/token existing.
# Without lazy, the recipe-compile-phase vault_fetch races vault-agent's
# first-run authentication on greenfield nodes and fails with "token
# sink not present".
# -------------------------------------------------------------------------------

# --- Configure the consul instance as a server or a client ---
consul_configure 'consul' do
  node_name(node[cookbook]['config']['node_name'] || node.name)
  bind_addr                           node[cookbook]['config']['bind_addr']
  datacenter                          node[cookbook]['config']['datacenter']
  client_addr                         node[cookbook]['config']['client_addr']
  server                              node[cookbook]['config']['server']
  bootstrap_expect                    node[cookbook]['config']['bootstrap_expect']
  retry_join                          node[cookbook]['config']['retry_join']
  node_meta                           node[cookbook]['config']['node_meta'].to_hash
  ports                               node[cookbook]['config']['ports'].to_hash
  ui_enabled                          node[cookbook]['config']['ui_enabled']
  connect_enabled                     node[cookbook]['config']['connect_enabled']
  raft_multiplier                     node[cookbook]['config']['raft_multiplier']
  acl_enabled                         node[cookbook]['config']['acl_enabled']
  acl_default_policy                  node[cookbook]['config']['acl_default_policy']
  acl_down_policy                     node[cookbook]['config']['acl_down_policy']
  # --- Lazy: vault_fetch runs at converge time; skipped when ACLs are disabled. ---
  # --- tokens.agent: consul-agent policy (agent's own ops only) ---
  acl_agent_token(lazy { node[cookbook]['config']['acl_enabled'] ? vault_fetch('secret/data/consul/agent-token', 'token') : nil })
  # --- tokens.default: nomad-client policy (broader scope; used by nomad and consul-template lookups via the local agent) ---
  acl_default_token(lazy { node[cookbook]['config']['acl_enabled'] ? vault_fetch('secret/data/consul/nomad-client-token', 'token') : nil })
  tls_enabled                         node[cookbook]['config']['tls_enabled']
  tls_ca_file                         node[cookbook]['config']['tls_ca_file']
  tls_cert_file                       node[cookbook]['config']['tls_cert_file']
  tls_key_file                        node[cookbook]['config']['tls_key_file']
  tls_verify_incoming                 node[cookbook]['config']['tls_verify_incoming']
  tls_verify_outgoing                 node[cookbook]['config']['tls_verify_outgoing']
  tls_verify_server_hostname          node[cookbook]['config']['tls_verify_server_hostname']
  telemetry_prometheus_retention_time node[cookbook]['config']['telemetry_prometheus_retention_time']
  telemetry_disable_hostname          node[cookbook]['config']['telemetry_disable_hostname']
  bin_path                            node[cookbook]['install']['bin_path']
  config_dir                          node[cookbook]['install']['config_dir']
  data_dir                            node[cookbook]['install']['data_dir']
  user                                node[cookbook]['install']['user']
  group                               node[cookbook]['install']['group']
end

# -------------------------------------------------------------------------------
# Nomad consul-sync recovery
#
# When consul restarts, Nomad's consul.sync loop notices missing service IDs
# on its next iteration but only issues UPDATE calls (404s), never re-CREATE.
# Result: every alloc-registered service on the node disappears from consul
# until something else kicks Nomad. Subscribing Nomad to a delayed restart on
# the consul restart forces Nomad's full reconcile path, which re-registers
# everything from its alloc state. Running containers stay up; only the agent
# process recycles. No-op on nodes without nomad (cinc-server, etc.).
# -------------------------------------------------------------------------------

service 'nomad' do
  action :nothing
  subscribes :restart, 'service[consul]', :delayed
  only_if { ::File.exist?('/etc/systemd/system/nomad.service') }
end
