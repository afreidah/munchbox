# -----------------------------------------------------------------------------
# CLOUDFLARE-WAF MODULE - OUTPUTS
# -----------------------------------------------------------------------------

output "managed_ruleset_ids" {
  description = "Map of zone name to the deployed managed-WAF ruleset id."
  value       = { for k, r in cloudflare_ruleset.managed : k => r.id }
}

output "bot_management_zones" {
  description = "Zone names with bot management configured."
  value       = keys(cloudflare_bot_management.this)
}
