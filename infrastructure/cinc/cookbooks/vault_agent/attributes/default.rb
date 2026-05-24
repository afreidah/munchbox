# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault_agent
# Attributes:: default
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Vault binary install
#
# Pulled from HashiCorp's apt repo. Same install path on debian + ubuntu.
# -------------------------------------------------------------------------------

# --- shared paths; both install + configure read these ---
default[cookbook]['binary_path'] = '/usr/bin/vault'
default[cookbook]['config_dir']  = '/etc/vault.d'

default[cookbook]['install'] = {
  package_name: 'vault',
  apt_repo_uri: 'https://apt.releases.hashicorp.com',
  apt_repo_key: 'https://apt.releases.hashicorp.com/gpg',
  # --- false on vault servers; binary already exists outside apt ---
  install_binary: true,
  # --- false on vault servers; vault.service IS the server ---
  mask_vault_service: true,
}

# -------------------------------------------------------------------------------
# Vault Agent configuration
#
# `role_id` (shared) + `secret_id` (per-node) are NOT here -- they come
# from the encrypted data bag `vault_agent/<node.name>` at converge time.
# This block holds the non-secret connection parameters only.
#
# `sink_path` is where vault-agent writes the maintained token; chef
# cookbooks read it via `::File.read(...)` and pass to `secret('hashi_vault')`.
# -------------------------------------------------------------------------------

# --- goren.munchbox.cc rather than the vault.munchbox.cc VIP because the current Vault server cert SANs are [goren, goren.munchbox.cc, localhost, vault.service.consul] -- once the cert is reissued with vault.munchbox.cc in the SAN list, flip this back to the VIP so HA failover works ---
default[cookbook]['config'] = {
  vault_addr: 'https://goren.munchbox.cc:8200',
  auth_mount: 'auth/chef-approle',
  sink_path: '/run/vault-agent/token',
  sink_mode: '0640',
}
