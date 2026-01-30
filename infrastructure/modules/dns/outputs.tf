# -----------------------------------------------------------------------------
# DNS MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Output Categories:
#   - Records: Created DNS record details
#   - Tunnel: Tunnel configuration reference
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DNS RECORDS
# -----------------------------------------------------------------------------

output "records" {
  description = "Map of created DNS records with their hostnames"
  value = {
    for key, record in cloudflare_record.records : key => {
      hostname = record.hostname
      type     = record.type
      proxied  = record.proxied
    }
  }
}

# -----------------------------------------------------------------------------
# TUNNEL
# -----------------------------------------------------------------------------

output "tunnel_config_id" {
  description = "Cloudflare tunnel configuration ID"
  value       = var.tunnel_config != null ? cloudflare_tunnel_config.tunnel[0].id : null
}
