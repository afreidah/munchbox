# -----------------------------------------------------------------------------
# CLOUDFLARE-WEB-ANALYTICS Module Outputs
# -----------------------------------------------------------------------------

output "site_tags" {
  description = "Web Analytics site identifier per zone. Identifies the beacon/site in the dashboard and API."
  value       = { for k, s in cloudflare_web_analytics_site.this : k => s.site_tag }
}

output "site_tokens" {
  description = "Web Analytics site token per zone. Public-by-design (embedded in the page beacon), not a secret."
  value       = { for k, s in cloudflare_web_analytics_site.this : k => s.site_token }
}

output "snippets" {
  description = "Encoded JS beacon snippet per zone, for gray-clouded sites that must embed the beacon manually."
  value       = { for k, s in cloudflare_web_analytics_site.this : k => s.snippet }
}
