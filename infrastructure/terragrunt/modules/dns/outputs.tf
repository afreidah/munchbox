# -----------------------------------------------------------------------------
# DNS Module Outputs
# -----------------------------------------------------------------------------

output "records" {
  description = "Map of created DNS records with their hostnames"
  value = {
    for key, record in cloudflare_dns_record.records : key => {
      hostname = record.name
      type     = record.type
      proxied  = record.proxied
    }
  }
}

output "tunnel_config_id" {
  description = "Cloudflare tunnel configuration ID"
  value       = var.tunnel_config != null ? cloudflare_zero_trust_tunnel_cloudflared_config.tunnel[0].id : null
}
