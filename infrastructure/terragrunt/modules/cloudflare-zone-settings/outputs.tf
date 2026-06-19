# -----------------------------------------------------------------------------
# CLOUDFLARE-ZONE-SETTINGS Module Outputs
# -----------------------------------------------------------------------------

output "dnssec_ds_records" {
  description = "Full DS record per zone; register at the domain registrar to activate DNSSEC."
  value       = { for k, z in cloudflare_zone_dnssec.this : k => z.ds }
}
