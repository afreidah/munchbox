# -----------------------------------------------------------------------------
# NOMAD-ACLS MODULE - OUTPUT VALUES
#
# Project: Munchbox / Author: Alex Freidah
#
# Output Categories:
#   - Policies: Map of created policy names
#   - Token Accessors: Safe-to-log accessor IDs for tokens
#   - Vault Paths: Where tokens are stored (not the tokens themselves)
#
# Usage:
#   - policies: Reference created policy names for verification
#   - token_accessors: Safe to log, use for token management
#   - vault_paths: Paths for applications to retrieve tokens from Vault
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# POLICIES
# -------------------------------------------------------------------------

output "policies" {
  description = "Map of created ACL policy names"
  value       = { for k, v in nomad_acl_policy.policy : k => v.name }
}

# -------------------------------------------------------------------------
# TOKEN ACCESSORS
# -------------------------------------------------------------------------

output "token_accessors" {
  description = "Map of token accessor IDs (safe to log)"
  value       = { for k, v in nomad_acl_token.token : k => v.accessor_id }
}

# -------------------------------------------------------------------------
# VAULT PATHS
# -------------------------------------------------------------------------

output "vault_paths" {
  description = "Vault KV paths where tokens are stored"
  value       = { for k, v in var.vault_secrets : k => "${var.vault_mount}/${v.vault_path}" }
}
