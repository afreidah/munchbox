# -------------------------------------------------------------------------------
# Outputs
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

output "cloudflare_records" {
  description = "Cloudflare DNS records created"
  value = [
    cloudflare_record.resume.hostname,
    cloudflare_record.resume_www.hostname,
    cloudflare_record.k3s_status.hostname,
    cloudflare_record.apex.hostname,
    cloudflare_record.www.hostname,
  ]
}
