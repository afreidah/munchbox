# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: vault_cert_manager
#
# Installs + configures vault-cert-manager (Vault PKI cert lifecycle
# daemon). Bundles install + configure recipes so per-node roles can
# include the role as a unit.
#
# Per-fleet roles populate `node[:vault_cert_manager][:certificates]`
# (e.g. role[oracle_node] sets consul-client + nomad-client cert
# definitions, with alt_names/ip_sans templated from per-node attrs).
# -------------------------------------------------------------------------------

name 'vault_cert_manager'
description 'Installs + configures vault-cert-manager'

run_list(
  'recipe[vault_cert_manager::install]',
  'recipe[vault_cert_manager::configure]'
)
