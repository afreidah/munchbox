# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: vault_server
#
# Runs HashiCorp Vault as an HA server (consul storage backend).
# Bundles vault::install + vault::configure recipes so per-node /
# per-fleet roles can include the role as a unit.
#
# Per-node roles must set:
#   - node[:vault][:config][:advertise_ip]                   (REQUIRED)
#   - the vault-server cert def in node[:vault_cert_manager][:certificates]
#
# Vault servers are shamir-sealed; this role NEVER auto-restarts vault
# on config change. The vault::configure resource defaults
# restart_on_change=false; only flip it true during planned maintenance.
# -------------------------------------------------------------------------------

name 'vault_server'
description 'Installs + configures HashiCorp Vault server (consul storage, shamir-sealed)'

run_list(
  'recipe[vault::install]',
  'recipe[vault::configure]'
)
