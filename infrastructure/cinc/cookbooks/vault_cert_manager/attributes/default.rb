# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault_cert_manager
# Attributes:: default
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Install / paths
#
# Package ships from the munchbox aptly repo. user/group default to root
# to match the existing ansible-managed deployments (vault-cert-manager
# needs to write cert files owned by consul/nomad, easiest as root).
# -------------------------------------------------------------------------------

default[cookbook]['install'] = {
  package_name: 'vault-cert-manager',
  config_dir: '/etc/vault-cert-manager',
  user: 'root',
  group: 'root',
}

# -------------------------------------------------------------------------------
# Daemon configuration
#
# vault address pinned to stabler for parity with the existing ansible
# config; revisit when the cluster vault_addr standardizes.
# pki_mount = pki_int (the intermediate CA that signs server/client certs).
# approle creds come from Vault via vault_fetch in the recipe.
# -------------------------------------------------------------------------------

default[cookbook]['config'] = {
  vault_address: 'https://192.168.68.61:8200',
  pki_mount: 'pki_int',
  skip_verify: false,
  approle_mount: 'approle',
  metrics_port: 9101,
  metrics_refresh: '30s',
  log_level: 'info',
  log_format: 'text',
}

# -------------------------------------------------------------------------------
# Vault paths
#
# Shared role_id + secret_id moved off the workstation's plaintext file
# into Vault. Both are fetched at converge time via munchbox_lib's
# vault_fetch (wrapped lazily per feedback_vault_fetch_lazy).
# -------------------------------------------------------------------------------

default[cookbook]['vault_paths'] = {
  role_id:   { path: 'secret/data/vault-cert-manager/role-id',   field: 'role_id' },
  secret_id: { path: 'secret/data/vault-cert-manager/secret-id', field: 'secret_id' },
}

# -------------------------------------------------------------------------------
# Consul service registration
# -------------------------------------------------------------------------------

default[cookbook]['consul_service_file'] = '/etc/consul.d/vault-cert-manager.json'

# -------------------------------------------------------------------------------
# Certificates list
#
# Each entry shape (matches the ansible/upstream config format):
#   { name:, role:, common_name:, certificate:, key:, ttl:,
#     alt_names: [..], ip_sans: [..],
#     owner:, group:, on_change:, health_check: { tcp:, timeout: } }
#
# Empty by default; populated per-fleet in the wrapping role
# (e.g. role[oracle_node] populates consul-client + nomad-client cert
# definitions, with alt_names/ip_sans templated from per-node attrs).
# -------------------------------------------------------------------------------

default[cookbook]['certificates'] = []

# --- Owners install ensures exist (in addition to those derived from certificates) ---
default[cookbook]['ensure_users'] = [
  { user: 'consul', group: 'consul' },
]
