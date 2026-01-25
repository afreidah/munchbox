# -------------------------------------------------------------------------------
# Nomad ACLs Module - Outputs
#
# Project: Munchbox / Author: Alex Freidah
#
# Exposes policy names, token accessor IDs, and Vault paths for verification.
# Token secrets are stored in Vault and intentionally not exposed here.
# -------------------------------------------------------------------------------

output "policies" {
  description = "Map of created ACL policy names"
  value = {
    admin         = nomad_acl_policy.admin.name
    read_only     = nomad_acl_policy.read_only.name
    developer     = nomad_acl_policy.developer.name
    hashi_ui      = nomad_acl_policy.hashi_ui.name
    backup_worker = nomad_acl_policy.backup_worker.name
    prometheus    = nomad_acl_policy.prometheus.name
  }
}

output "token_accessors" {
  description = "Map of token accessor IDs (safe to log)"
  value = {
    hashi_ui      = nomad_acl_token.hashi_ui.accessor_id
    backup_worker = nomad_acl_token.backup_worker.accessor_id
    prometheus    = nomad_acl_token.prometheus.accessor_id
  }
}

output "vault_paths" {
  description = "Vault KV paths where tokens are stored"
  value = {
    hashi_ui      = "${var.vault_mount}/hashiuisecret"
    backup_worker = "${var.vault_mount}/backup-worker"
    prometheus    = "${var.vault_mount}/prometheus-nomad"
  }
}
