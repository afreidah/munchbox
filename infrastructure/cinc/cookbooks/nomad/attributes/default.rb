# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nomad
# Attributes:: default
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Binary install
#
# Pinned to the version currently running in the munchbox cluster.
# -------------------------------------------------------------------------------

# --- user/group default to root for parity with ansible (state trees under /var/lib/nomad are root-owned). ---
default[cookbook]['install'] = {
  version: '2.0.3',
  bin_path: '/usr/local/bin/nomad',
  user: 'root',
  group: 'root',
  config_dir: '/etc/nomad.d',
  data_dir: '/var/lib/nomad',
  log_dir: '/var/log/nomad',
}

# -------------------------------------------------------------------------------
# Agent configuration
#
# TLS cert paths point at the layout vault-cert-manager already writes
# (/etc/nomad.d/tls/{nomad.crt, nomad.key, ca-chain.crt}); this cookbook
# never touches the cert files themselves.
# -------------------------------------------------------------------------------

default[cookbook]['config'] = {
  datacenter: 'munchbox',
  region: 'global',
  log_level: 'INFO',

  node_name: nil,  # required, per-node
  bind_addr: nil,  # required, per-node
  advertise_ip: nil, # required, per-node
  advertise_http_port: 4646,
  advertise_rpc_port: 4647,
  advertise_serf_port: 4648,

  server_enabled: false,
  bootstrap_expect: nil,
  server_join: [], # array of "<ip>:4648"

  client_enabled: true,
  servers: [], # array of "<ip>:4647" (clients only)
  node_pool: 'default',
  node_class: nil, # optional client.node_class string (rendered only when set)
  client_meta: {}, # extra meta beyond auto arch
  # --- Ansible-era orphans to sweep on every converge. Goren/stabler default below; other fleets can append. ---
  stale_paths: [
    '/etc/nomad.d/nomad.hcl.bak',
    '/etc/nomad.d/nomad.hcl.broken',
    '/etc/nomad.d/consul_token.env',
    '/etc/nomad.d/010-client-tags.hcl',
    '/etc/systemd/system/nomad.service.d/10-consul-token.conf',
  ],
  network_interface: nil, # nil = let nomad auto-detect
  gc_disk_usage_threshold: 80,
  gc_inode_usage_threshold: 70,

  # --- Consul integration ---
  consul_enabled: true,
  consul_address: '127.0.0.1:8501',
  consul_datacenter: 'munchbox',
  consul_ssl: true,
  consul_ca_file: '/etc/consul.d/tls/ca.crt',
  consul_cert_file: '/etc/consul.d/tls/consul.crt',
  consul_key_file: '/etc/consul.d/tls/consul.key',

  # --- Vault integration (workload identity; nomad signs JWTs that vault accepts via nomad-jwt mount) ---
  vault_enabled: true,

  # --- Pinned to stabler for parity with the live ansible-managed config; revisit when the cluster vault_addr standardizes. ---
  vault_address: 'https://192.168.68.61:8200',
  vault_ca_file: '/opt/nomad/tls/vault-intermediate-ca.pem',
  vault_default_identity_aud: ['vault.io'],
  vault_default_identity_ttl: '1h',

  acl_enabled: true,

  # --- TLS ---
  tls_http: true,
  tls_rpc: true,
  tls_ca_file: '/etc/nomad.d/tls/ca.crt',
  tls_cert_file: '/etc/nomad.d/tls/nomad.crt',
  tls_key_file: '/etc/nomad.d/tls/nomad.key',
  tls_verify_server_hostname: true,
  tls_verify_https_client: false,

  # --- Docker plugin (client-only; rendered when client_enabled=true) ---
  docker_allow_privileged: true,
  docker_allow_caps: %w(audit_write chown dac_override fowner fsetid kill mknod net_bind_service setfcap setgid setpcap setuid sys_chroot net_admin net_raw),
  docker_volumes_enabled: true,
  docker_gc_image: true,
  docker_gc_image_delay: '3m',
  docker_gc_container: true,
  docker_gc_dangling_period: '5m',
  docker_gc_dangling_grace: '5m',

  # --- Telemetry ---
  telemetry_prometheus_metrics: true,
  telemetry_disable_hostname: false,
  telemetry_publish_alloc_metrics: true,
  telemetry_publish_node_metrics: true,
}

# -------------------------------------------------------------------------------
# AlertManager POSTs alerts here; the receiver scans for labels
# `auto_restart=true` + `nomad_job=<name>` and shells out to
# `nomad job restart` (with a per-job cooldown to absorb flapping).
#
# Opt-in: include `recipe[nomad::auto_restart_webhook]` only on the
# node(s) that should run the receiver. Currently stabler-only.
#
# Port must match AlertManager's webhook URL
# (monitoring/alertmanager/files/alertmanager.yml.tpl). The pre-takeover
# python script silently drifted to 9099 and got out of sync with
# AlertManager (9095); the consul check has been red ever since.
# -------------------------------------------------------------------------------

default[cookbook]['auto_restart_webhook'] = {
  # --- Identity / service ---
  service_name: 'nomad-auto-restart-webhook',
  service_description: 'AlertManager Webhook for Nomad Job Auto-Restart',
  user: 'root',
  group: 'root',

  # --- Network / receiver behavior ---
  port: 9095,
  bind_address: '0.0.0.0',
  cooldown_seconds: 300,
  cooldown_dir: '/tmp/nomad-restart-cooldown',
  log_file: '/var/log/nomad-auto-restart.log',

  # --- On-disk paths ---
  python_bin: '/usr/bin/python3',
  script_path: '/usr/local/bin/nomad-auto-restart-webhook.py',

  # --- Systemd dependencies ---
  after_units: %w(network.target nomad.service),
  wants_units: %w(nomad.service),
  restart_policy: 'always',
  restart_sec: 5,

  # --- Nomad client env (mTLS to the local agent) ---
  nomad_addr: 'https://127.0.0.1:4646',
  nomad_cacert: '/etc/nomad.d/tls/ca.crt',
  nomad_client_cert: '/etc/nomad.d/tls/nomad.crt',
  nomad_client_key: '/etc/nomad.d/tls/nomad.key',

  # --- Consul service registration ---
  consul_service_file: '/etc/consul.d/nomad-auto-restart-webhook.json',
  consul_service_name: 'nomad-auto-restart-webhook',
  consul_service_tags: %w(alertmanager webhook infrastructure),
  consul_check_path: '/',
  consul_check_interval: '30s',
  consul_check_timeout: '5s',
  consul_user: 'consul',
  consul_group: 'consul',

  # --- Bash predecessor (replaced by python); swept on every converge. ---
  stale_paths: [
    '/usr/local/bin/nomad-auto-restart-webhook.sh',
  ],

  vault_paths: {
    # --- Restart-only token (read + alloc-lifecycle); minted by the nomad-acls terragrunt module, NOT the management token. ---
    nomad_token: { path: 'secret/data/nomad/auto-restart-webhook', field: 'token' },
  },

  # --- nil by default; recipe lazy-fetches from Vault. Override to a literal for kitchen / break-glass. ---
  nomad_token: nil,
}
