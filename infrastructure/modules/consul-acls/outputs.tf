# -----------------------------------------------------------------------------
# CONSUL-ACLS MODULE - OUTPUT VALUES
#
# Project: Munchbox / Author: Alex Freidah
#
# Output Categories:
#   - Policies: Map of created policy names
#   - Vault Paths: Where tokens are stored (not the tokens themselves)
#
# Usage:
#   - policies: Reference created policy names for verification
#   - vault_paths: Paths for Ansible/applications to retrieve tokens from Vault
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# POLICIES
# -------------------------------------------------------------------------

output "policies" {
  description = "Map of created ACL policy names"
  value       = { for k, v in consul_acl_policy.policy : k => v.name }
}

# -------------------------------------------------------------------------
# VAULT PATHS
# -------------------------------------------------------------------------

output "vault_paths" {
  description = "Vault KV paths where tokens are stored"
  value = merge(
    var.store_bootstrap_token ? { bootstrap = "${var.vault_mount}/consul/bootstrap-token" } : {},
    { for k, v in var.vault_secrets : k => "${var.vault_mount}/${v.vault_path}" }
  )
}
