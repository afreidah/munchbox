# -----------------------------------------------------------------------------
# CLOUDFLARE-API-TOKEN MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "token_values" {
  description = "Map of token request key to the secret token value."
  value       = { for k, t in cloudflare_api_token.this : k => t.value }
  sensitive   = true
}

output "token_ids" {
  description = "Map of token request key to Cloudflare token ID."
  value       = { for k, t in cloudflare_api_token.this : k => t.id }
}

output "vault_data" {
  description = "Per-token Vault-ready data keyed by token name: { <name> = { api_token = <value> } }. Consumed by the vault-secrets leaf, indexed by token name."
  value       = { for k, t in cloudflare_api_token.this : k => { api_token = t.value } }
  sensitive   = true
}
