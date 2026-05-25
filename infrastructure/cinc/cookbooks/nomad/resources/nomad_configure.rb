# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nomad
# Resource:: nomad_configure
#
# Drops /etc/nomad.d/nomad.hcl + the systemd unit, then enables and
# starts nomad. Server/client mode toggled via the server_enabled +
# client_enabled properties (a node can be both, neither just won't
# render any orchestrator config and nomad will refuse to start).
#
# TLS material is owned out-of-band by vault-cert-manager (server +
# client certs at /etc/nomad.d/tls/). Vault PKI CA is hand-staged at
# /opt/nomad/tls/vault-intermediate-ca.pem for the Vault integration.
# Consul ACL agent token is fetched from Vault at converge time.
# -------------------------------------------------------------------------------

unified_mode true

provides :nomad_configure

property :node_name,                  String, required: true
property :bind_addr,                  String, required: true
property :advertise_ip,               String, required: true
property :advertise_http_port,        Integer, default: 4646
property :advertise_rpc_port,         Integer, default: 4647
property :advertise_serf_port,        Integer, default: 4648
property :datacenter,                 String, default: 'munchbox'
property :region,                     String, default: 'global'
property :log_level,                  String, default: 'INFO'

property :server_enabled,             [true, false], default: false
property :bootstrap_expect,           [Integer, nil]
property :server_join,                Array, default: []

property :client_enabled,             [true, false], default: true
property :servers,                    Array, default: []
property :node_pool,                  String, default: 'default'
property :node_class,                 [String, nil]
property :client_meta,                Hash, default: {}
property :network_interface,          [String, nil]
property :gc_disk_usage_threshold,    Integer, default: 80
property :gc_inode_usage_threshold,   Integer, default: 70

property :consul_enabled,             [true, false], default: true
property :consul_address,             String, default: '127.0.0.1:8501'
property :consul_datacenter,          String, default: 'munchbox'
property :consul_ssl,                 [true, false], default: true
property :consul_ca_file,             String, default: '/etc/consul.d/tls/ca.crt'
property :consul_cert_file,           String, default: '/etc/consul.d/tls/consul.crt'
property :consul_key_file,            String, default: '/etc/consul.d/tls/consul.key'
property :consul_token,               [String, nil], sensitive: true

property :vault_enabled,              [true, false], default: true
property :vault_address,              String, default: 'https://192.168.68.61:8200'
property :vault_ca_file,              String, default: '/opt/nomad/tls/vault-intermediate-ca.pem'
property :vault_default_identity_aud, Array, default: ['vault.io']
property :vault_default_identity_ttl, String, default: '1h'

property :acl_enabled,                [true, false], default: true

property :tls_http,                   [true, false], default: true
property :tls_rpc,                    [true, false], default: true
property :tls_ca_file,                String, default: '/etc/nomad.d/tls/ca.crt'
property :tls_cert_file,              String, default: '/etc/nomad.d/tls/nomad.crt'
property :tls_key_file,               String, default: '/etc/nomad.d/tls/nomad.key'
property :tls_verify_server_hostname, [true, false], default: true
property :tls_verify_https_client,    [true, false], default: false

property :docker_allow_privileged,    [true, false], default: true
property :docker_allow_caps,          Array, default: %w(audit_write chown dac_override fowner fsetid kill mknod net_bind_service setfcap setgid setpcap setuid sys_chroot net_admin net_raw)
property :docker_volumes_enabled,     [true, false], default: true
property :docker_gc_image,            [true, false], default: true
property :docker_gc_image_delay,      String, default: '3m'
property :docker_gc_container,        [true, false], default: true
property :docker_gc_dangling_period,  String, default: '5m'
property :docker_gc_dangling_grace,   String, default: '5m'

property :telemetry_prometheus_metrics,    [true, false], default: true
property :telemetry_disable_hostname,      [true, false], default: false
property :telemetry_publish_alloc_metrics, [true, false], default: true
property :telemetry_publish_node_metrics,  [true, false], default: true

property :bin_path,                   String, default: '/usr/local/bin/nomad'
property :config_dir,                 String, default: '/etc/nomad.d'
property :data_dir,                   String, default: '/var/lib/nomad'
property :user,                       String, default: 'nomad'
property :group,                      String, default: 'nomad'

# --- Orphan files (ansible-era drop-ins, .bak/.broken, conflicting client {} blocks) swept on every converge. Empty by default; set per-role/per-node. ---
property :stale_paths,                Array, default: []

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure
# -------------------------------------------------------------------------------

action :configure do
  # --- Fail-fast guards; nomad would otherwise start and crash mid-converge ---
  if new_resource.server_enabled && new_resource.bootstrap_expect.nil?
    raise "nomad_configure[#{new_resource.name}]: server_enabled=true requires bootstrap_expect"
  end
  raise "nomad_configure[#{new_resource.name}]: client_enabled=true requires servers list" if new_resource.client_enabled && new_resource.servers.empty?
  raise "nomad_configure[#{new_resource.name}]: consul_enabled=true requires consul_token (check secret/consul/agent-token in Vault)" if new_resource.consul_enabled && new_resource.consul_token.to_s.empty?

  # --- daemon-reload runs immediately when a systemd drop-in gets swept; otherwise systemd holds the stale unit spec and refuses to restart. ---
  execute 'systemctl daemon-reload (nomad stale-paths sweep)' do
    command 'systemctl daemon-reload'
    action :nothing
  end

  # --- Sweep ansible-era orphans (drop-ins with dead tokens, conflicting *.hcl, .bak/.broken). ---
  new_resource.stale_paths.each do |path|
    file path do
      action :delete
      # --- Reload systemd if we just removed a unit drop-in. ---
      notifies :run, 'execute[systemctl daemon-reload (nomad stale-paths sweep)]', :immediately if path.start_with?('/etc/systemd/')
    end
  end

  template "#{new_resource.config_dir}/nomad.hcl" do
    source 'nomad.hcl.erb'
    owner  new_resource.user
    group  new_resource.group
    mode   '0640'
    sensitive true
    variables(
      node_name: new_resource.node_name,
      bind_addr: new_resource.bind_addr,
      advertise_ip: new_resource.advertise_ip,
      advertise_http_port: new_resource.advertise_http_port,
      advertise_rpc_port: new_resource.advertise_rpc_port,
      advertise_serf_port: new_resource.advertise_serf_port,
      datacenter: new_resource.datacenter,
      region: new_resource.region,
      log_level: new_resource.log_level,
      data_dir: new_resource.data_dir,
      server_enabled: new_resource.server_enabled,
      bootstrap_expect: new_resource.bootstrap_expect,
      server_join: new_resource.server_join,
      client_enabled: new_resource.client_enabled,
      servers: new_resource.servers,
      node_pool: new_resource.node_pool,
      node_class: new_resource.node_class,
      client_meta: new_resource.client_meta,
      network_interface: new_resource.network_interface,
      gc_disk_usage_threshold: new_resource.gc_disk_usage_threshold,
      gc_inode_usage_threshold: new_resource.gc_inode_usage_threshold,
      arch: arch_meta,
      consul_enabled: new_resource.consul_enabled,
      consul_address: new_resource.consul_address,
      consul_datacenter: new_resource.consul_datacenter,
      consul_ssl: new_resource.consul_ssl,
      consul_ca_file: new_resource.consul_ca_file,
      consul_cert_file: new_resource.consul_cert_file,
      consul_key_file: new_resource.consul_key_file,
      consul_token: new_resource.consul_token,
      vault_enabled: new_resource.vault_enabled,
      vault_address: new_resource.vault_address,
      vault_ca_file: new_resource.vault_ca_file,
      vault_default_identity_aud: new_resource.vault_default_identity_aud,
      vault_default_identity_ttl: new_resource.vault_default_identity_ttl,
      acl_enabled: new_resource.acl_enabled,
      tls_http: new_resource.tls_http,
      tls_rpc: new_resource.tls_rpc,
      tls_ca_file: new_resource.tls_ca_file,
      tls_cert_file: new_resource.tls_cert_file,
      tls_key_file: new_resource.tls_key_file,
      tls_verify_server_hostname: new_resource.tls_verify_server_hostname,
      tls_verify_https_client: new_resource.tls_verify_https_client,
      docker_allow_privileged: new_resource.docker_allow_privileged,
      docker_allow_caps: new_resource.docker_allow_caps,
      docker_volumes_enabled: new_resource.docker_volumes_enabled,
      docker_gc_image: new_resource.docker_gc_image,
      docker_gc_image_delay: new_resource.docker_gc_image_delay,
      docker_gc_container: new_resource.docker_gc_container,
      docker_gc_dangling_period: new_resource.docker_gc_dangling_period,
      docker_gc_dangling_grace: new_resource.docker_gc_dangling_grace,
      telemetry_prometheus_metrics: new_resource.telemetry_prometheus_metrics,
      telemetry_disable_hostname: new_resource.telemetry_disable_hostname,
      telemetry_publish_alloc_metrics: new_resource.telemetry_publish_alloc_metrics,
      telemetry_publish_node_metrics: new_resource.telemetry_publish_node_metrics
    )
    notifies :restart, 'systemd_unit[nomad.service]', :delayed
  end

  systemd_unit 'nomad.service' do
    content <<~UNIT
      [Unit]
      Description=Nomad
      Documentation=https://www.nomadproject.io/docs/
      Requires=network-online.target
      After=network-online.target
      ConditionFileNotEmpty=#{new_resource.config_dir}/nomad.hcl

      [Service]
      Type=notify
      User=#{new_resource.user}
      Group=#{new_resource.group}
      KillMode=process
      Restart=on-failure
      RestartSec=2
      ExecStart=#{new_resource.bin_path} agent -config=#{new_resource.config_dir}

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
  systemd_unit 'nomad.service' do
    action %i(disable stop delete)
  end

  file "#{new_resource.config_dir}/nomad.hcl" do
    action :delete
  end
end

# --- Auto-detect the client meta `arch` field from ohai (arm64 for Pi5/oracle-arm, amd64 elsewhere) ---
action_class do
  def arch_meta
    case node['kernel']['machine']
    when 'aarch64', 'arm64' then 'arm64'
    else 'amd64'
    end
  end
end
