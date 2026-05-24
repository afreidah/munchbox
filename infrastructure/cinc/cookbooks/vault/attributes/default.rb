# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault
# Attributes:: default
#
# Vault server. NOT vault-agent (that's the vault_agent cookbook). NOT
# vault-cert-manager (that's vault_cert_manager). This cookbook drives
# the vault server daemon itself: binary install + vault.hcl + systemd
# unit.
#
# Critical behavior: vault servers are shamir-sealed (5 shares,
# threshold 3). A restart requires manual unseal x3 per node to recover.
# As a result THIS COOKBOOK DOES NOT auto-restart vault on config
# changes. The config gets rewritten on disk; vault picks it up at the
# next planned restart (operator action). TLS cert rotation is handled
# out-of-band by vault-cert-manager via SIGHUP (safe, no unseal needed).
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Binary install
#
# Pinned to the version currently running in the munchbox cluster.
# Bumping = re-upload + planned restart cycle (each node = restart +
# manual unseal x3).
# -------------------------------------------------------------------------------

default[cookbook]['install'] = {
  version:    '2.0.1',
  bin_path:   '/usr/local/bin/vault',
  user:       'vault',
  group:      'vault',
  config_dir: '/etc/vault.d',
  data_dir:   '/opt/vault/data',
  tls_dir:    '/etc/vault.d/tls',
}

# -------------------------------------------------------------------------------
# Server configuration
#
# Per-node knobs to override in the role:
#   advertise_ip      -- IP for api_addr + cluster_addr + listener.cluster_address. REQUIRED.
#   node_id           -- optional override; cookbook defaults to node.name.
#
# Everything else (storage backend, listener address, cluster_name, ui,
# telemetry) is cookbook-wide and matches the existing ansible-managed
# config on all 3 vault servers.
#
# TLS cert paths point at the layout vault-cert-manager will write
# (/etc/vault.d/tls/{vault.crt, vault.key}); this cookbook never
# touches the cert files themselves.
# -------------------------------------------------------------------------------

default[cookbook]['config'] = {
  cluster_name:    'munchbox-vault',
  log_level:       'info',
  ui_enabled:      true,
  disable_mlock:   false,

  advertise_ip:    nil, # required, per-node

  # --- Listener ---
  listener_address: '0.0.0.0:8200',
  listener_tls_disable: false,
  listener_tls_cert_file: '/etc/vault.d/tls/vault.crt',
  listener_tls_key_file:  '/etc/vault.d/tls/vault.key',

  # --- Cluster (api_addr / cluster_addr scheme + port; addr IP comes from advertise_ip) ---
  api_scheme:      'https',
  api_port:        8200,
  cluster_port:    8201,

  # --- Consul storage backend ---
  storage_enabled:    true,
  storage_address:    '127.0.0.1:8501',
  storage_scheme:     'https',
  storage_path:       'vault/',
  storage_tls_ca_file:   '/etc/consul.d/tls/ca-chain.crt',
  storage_tls_cert_file: '/etc/consul.d/tls/consul.crt',
  storage_tls_key_file:  '/etc/consul.d/tls/consul.key',

  # --- Service registration (also via consul) ---
  service_registration_enabled: true,

  # --- Telemetry ---
  telemetry_disable_hostname:           false,
  telemetry_prometheus_retention_time:  '30s',
  telemetry_usage_gauge_period:         '10m',
  telemetry_enable_hostname_label:      true,

  # --- Restart safety knob; shamir = manual unseal x3 per restart. Default off; only flip true during planned maintenance windows. ---
  restart_on_change: false,

  # --- Files to sweep on every converge (ansible-era backups, fullchain bundle stabler has, etc). ---
  stale_paths: [],
}

# -------------------------------------------------------------------------------
# Vault paths
#
# Consul storage backend ACL token + service registration ACL token are
# the same value (vault-storage policy). Fetched at converge time via
# vault_fetch.
# -------------------------------------------------------------------------------

default[cookbook]['vault_paths'] = {
  consul_storage_token: {
    path:  'secret/data/consul/vault-storage-token',
    field: 'token',
  },
}
