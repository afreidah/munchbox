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
# All vault servers use OCI KMS auto-unseal (seal config set below; private
# key from the vault_unseal data bag). This role NEVER auto-restarts vault on
# config change -- restart_on_change defaults false; flip it true only during
# planned maintenance.
# -------------------------------------------------------------------------------

name 'vault_server'
description 'Installs + configures HashiCorp Vault server (consul storage; shamir or OCI KMS auto-unseal)'

run_list(
  'recipe[vault::install]',
  'recipe[vault::configure]'
)

# --- vault-agent on the server nodes reaches Vault via consul DNS (any healthy,
#     unsealed server) instead of the single goren default, so a sealed local vault
#     no longer wedges this node's converge. Override (not default) because the
#     cookbook sets config as a Hash literal. Steady-state only: these servers
#     always have consul up; a brand-new vault server still bootstraps on the
#     cookbook default first. ---
override_attributes(
  'vault_agent' => { 'config' => { 'vault_addr' => 'https://vault.service.consul:8200' } },

  # --- OCI KMS auto-unseal, all vault servers; private key from the vault_unseal data bag ---
  'vault' => {
    'seal' => {
      'enabled' => true,
      'key_id' => 'ocid1.key.oc1.phx.efuxgqqxaagsq.abyhqljsv5fshqfnhsaeplahsq3qwkdkdxecu33yb6yquwdhqnrg56irupnq',
      'crypto_endpoint' => 'https://efuxgqqxaagsq-crypto.kms.us-phoenix-1.oraclecloud.com',
      'management_endpoint' => 'https://efuxgqqxaagsq-management.kms.us-phoenix-1.oraclecloud.com',
      'tenancy_ocid' => 'ocid1.tenancy.oc1..aaaaaaaaeyhaous2t76u676i73cr4wi2turtytmu2j2muyiyvrboqpsp5z7a',
      'user_ocid' => 'ocid1.user.oc1..aaaaaaaa46rjfkjfy5i3uvyzzg6utitevx22frv5gvqzomomkop6t2m2kq4q',
      'fingerprint' => 'd3:19:f2:89:41:52:c1:ff:1f:5f:98:7a:ee:c9:e1:68',
      'region' => 'us-phoenix-1',
    },
  }
)
