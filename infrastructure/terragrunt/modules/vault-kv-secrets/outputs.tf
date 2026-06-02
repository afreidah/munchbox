# -----------------------------------------------------------------------------
# VAULT-KV-SECRETS MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "vault_paths" {
  description = "Map of secret name to its full Vault path."
  value       = { for k, s in vault_kv_secret_v2.this : k => "${s.mount}/data/${s.name}" }
}
