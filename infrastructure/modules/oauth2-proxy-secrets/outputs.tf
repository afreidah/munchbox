# -----------------------------------------------------------------------------
# OAUTH2-PROXY SECRETS MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "vault_path" {
  description = "Full Vault path to the oauth2-proxy secret"
  value       = "${var.vault_mount}/data/${vault_kv_secret_v2.oauth2_proxy.name}"
}

output "secret_name" {
  description = "Name of the Vault secret"
  value       = vault_kv_secret_v2.oauth2_proxy.name
}
