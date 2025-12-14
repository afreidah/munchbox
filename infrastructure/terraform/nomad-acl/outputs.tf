# -------------------------------------------------------------------------------
# Nomad ACL Configuration - Outputs
#
# Project: Munchbox / Author: Alex Freidah
#
# Exposes policy names, token accessor IDs, and Vault secret paths. Accessor IDs
# are safe to log. Actual token secrets are stored only in Vault.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Policy Names
# -----------------------------------------------------------------------------

output "policy_admin" {
  description = "Admin policy name"
  value       = nomad_acl_policy.admin.name
}

output "policy_read_only" {
  description = "Read-only policy name"
  value       = nomad_acl_policy.read_only.name
}

output "policy_developer" {
  description = "Developer policy name"
  value       = nomad_acl_policy.developer.name
}

# -----------------------------------------------------------------------------
# Token Accessor IDs (safe to log)
# -----------------------------------------------------------------------------

output "token_hashi_ui_accessor" {
  description = "Hashi-UI token accessor ID"
  value       = nomad_acl_token.hashi_ui.accessor_id
}

output "token_backup_worker_accessor" {
  description = "Backup worker token accessor ID"
  value       = nomad_acl_token.backup_worker.accessor_id
}

output "token_prometheus_accessor" {
  description = "Prometheus token accessor ID"
  value       = nomad_acl_token.prometheus.accessor_id
}

# -----------------------------------------------------------------------------
# Vault Secret Paths
# -----------------------------------------------------------------------------

output "vault_path_hashi_ui" {
  description = "Vault path for hashi-ui token"
  value       = "secret/data/hashiuisecret"
}

output "vault_path_backup_worker" {
  description = "Vault path for backup-worker token"
  value       = "kv/data/backup-worker"
}

output "vault_path_prometheus_nomad" {
  description = "Vault path for prometheus nomad token"
  value       = "kv/data/prometheus-nomad"
}
