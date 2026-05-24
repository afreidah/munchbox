# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: consul
# Resource:: consul_configure
#
# Drops /etc/consul.d/consul.hcl + the systemd unit, then enables and
# starts consul. Server/client mode toggles off the `server` property.
#
# TLS material is owned out-of-band by vault-cert-manager (server +
# client certs land at the paths in `tls_cert_file` / `tls_key_file`).
# ACL agent token is fetched from Vault at converge time.
#
# Properties:
#   node_name        - consul node name (required).
#   bind_addr        - IP to bind RPC/serf to (required).
#   datacenter       - cluster datacenter (default 'munchbox').
#   client_addr      - DNS/HTTP listen address (default '0.0.0.0').
#   server           - true for cluster servers, false for clients.
#   bootstrap_expect - integer; only emitted when server=true.
#   retry_join       - array of IPs/hostnames to attempt joining (required).
#   node_meta        - Hash rendered as a node_meta {} block (default {}).
#   ports            - Hash of named ports (dns, http, https, grpc, ...).
#   ui_enabled       - default true.
#   connect_enabled  - default true.
#   raft_multiplier  - default 1.
#   acl_agent_token  - sensitive; emitted into acl.tokens.agent (used by
#                      the consul agent for its OWN ops: gossip, anti-entropy,
#                      self-registration).
#   acl_default_token - sensitive; emitted into acl.tokens.default (used by
#                      ANY local API caller that doesn't pass its own token,
#                      including nomad's consul client and consul-template
#                      template stanzas). Needs broader KV/service read than
#                      acl_agent_token.
#   tls_*            - cert/key paths + verify_* flags (consumed verbatim).
#   acl_*            - default policy + down policy.
#   telemetry_*      - prometheus retention + disable_hostname flag.
#   bin_path         - consul binary path (default /usr/local/bin/consul).
#   config_dir       - default /etc/consul.d.
#   data_dir         - default /opt/consul/data.
#   user / group     - service user (default consul/consul).
# -------------------------------------------------------------------------------

unified_mode true

provides :consul_configure

property :node_name,                  String, required: true
property :bind_addr,                  String, required: true
property :datacenter,                 String, default: 'munchbox'
property :client_addr,                String, default: '0.0.0.0'
property :server,                     [true, false], default: false
property :bootstrap_expect,           [Integer, nil]
property :retry_join,                 Array,  default: []
property :node_meta,                  Hash,   default: {}
property :ports,                      Hash,   default: {
  'dns' => 8600, 'http' => 8500, 'https' => 8501, 'grpc' => 8502,
  'grpc_tls' => 8503, 'serf_lan' => 8301, 'serf_wan' => 8302, 'server' => 8300
}
property :ui_enabled,                 [true, false], default: true
property :connect_enabled,            [true, false], default: true
property :raft_multiplier,            Integer, default: 1
property :acl_enabled,                [true, false], default: true
property :acl_default_policy,         String, default: 'deny'
property :acl_down_policy,            String, default: 'extend-cache'
property :acl_agent_token,            [String, nil], sensitive: true
property :acl_default_token,          [String, nil], sensitive: true
property :tls_enabled,                [true, false], default: true
property :tls_ca_file,                String, default: '/etc/consul.d/tls/ca-chain.crt'
property :tls_cert_file,              String, default: '/etc/consul.d/tls/consul.crt'
property :tls_key_file,               String, default: '/etc/consul.d/tls/consul.key'
property :tls_verify_incoming,        [true, false], default: true
property :tls_verify_outgoing,        [true, false], default: true
property :tls_verify_server_hostname, [true, false], default: true
property :telemetry_prometheus_retention_time, String, default: '30s'
property :telemetry_disable_hostname, [true, false], default: false
property :bin_path,                   String, default: '/usr/local/bin/consul'
property :config_dir,                 String, default: '/etc/consul.d'
property :data_dir,                   String, default: '/opt/consul/data'
property :user,                       String, default: 'consul'
property :group,                      String, default: 'consul'

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure
# -------------------------------------------------------------------------------

action :configure do
  # --- fail fast if server-mode is missing its quorum size, rather than letting consul refuse to bootstrap ---
  if new_resource.server && new_resource.bootstrap_expect.nil?
    raise "consul_configure[#{new_resource.name}]: server=true requires bootstrap_expect"
  end
  raise "consul_configure[#{new_resource.name}]: retry_join must be non-empty" if new_resource.retry_join.empty?
  raise "consul_configure[#{new_resource.name}]: acl_agent_token is empty (check secret/consul/agent-token in Vault)" if new_resource.acl_enabled && new_resource.acl_agent_token.to_s.empty?
  raise "consul_configure[#{new_resource.name}]: acl_default_token is empty (check secret/consul/nomad-client-token in Vault)" if new_resource.acl_enabled && new_resource.acl_default_token.to_s.empty?

  template "#{new_resource.config_dir}/consul.hcl" do
    source 'consul.hcl.erb'
    owner  new_resource.user
    group  new_resource.group
    mode   '0640'
    sensitive true
    variables(
      node_name: new_resource.node_name,
      bind_addr: new_resource.bind_addr,
      datacenter: new_resource.datacenter,
      client_addr: new_resource.client_addr,
      data_dir: new_resource.data_dir,
      server: new_resource.server,
      bootstrap_expect: new_resource.bootstrap_expect,
      retry_join: new_resource.retry_join,
      node_meta: new_resource.node_meta,
      ports: new_resource.ports,
      ui_enabled: new_resource.ui_enabled,
      connect_enabled: new_resource.connect_enabled,
      raft_multiplier: new_resource.raft_multiplier,
      acl_enabled: new_resource.acl_enabled,
      acl_default_policy: new_resource.acl_default_policy,
      acl_down_policy: new_resource.acl_down_policy,
      acl_agent_token: new_resource.acl_agent_token,
      acl_default_token: new_resource.acl_default_token,
      tls_enabled: new_resource.tls_enabled,
      tls_ca_file: new_resource.tls_ca_file,
      tls_cert_file: new_resource.tls_cert_file,
      tls_key_file: new_resource.tls_key_file,
      tls_verify_incoming: new_resource.tls_verify_incoming,
      tls_verify_outgoing: new_resource.tls_verify_outgoing,
      tls_verify_server_hostname: new_resource.tls_verify_server_hostname,
      telemetry_prometheus_retention_time: new_resource.telemetry_prometheus_retention_time,
      telemetry_disable_hostname: new_resource.telemetry_disable_hostname
    )
    notifies :restart, 'systemd_unit[consul.service]', :delayed
  end

  # --- Systemd unit; Type=notify lets systemd track agent readiness ---
  systemd_unit 'consul.service' do
    content <<~UNIT
      [Unit]
      Description=Consul Agent
      Documentation=https://www.consul.io/docs/
      Requires=network-online.target
      After=network-online.target
      ConditionFileNotEmpty=#{new_resource.config_dir}/consul.hcl

      [Service]
      Type=notify
      User=#{new_resource.user}
      Group=#{new_resource.group}
      ExecStart=#{new_resource.bin_path} agent -config-dir=#{new_resource.config_dir}
      ExecReload=/bin/kill --signal HUP $MAINPID
      KillMode=process
      KillSignal=SIGTERM
      Restart=on-failure
      RestartSec=5
      LimitNOFILE=65536

      [Install]
      WantedBy=multi-user.target
    UNIT
    action %i(create enable start)
  end
end

# -------------------------------------------------------------------------------
# Action :remove
# -------------------------------------------------------------------------------

action :remove do
  systemd_unit 'consul.service' do
    action %i(disable stop delete)
  end

  file "#{new_resource.config_dir}/consul.hcl" do
    action :delete
  end
end
