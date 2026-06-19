# -----------------------------------------------------------------------------
# CLOUDFLARE-ZONE-SETTINGS MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "zone_settings" {
  description = "Map of per-zone settings keyed by \"<zone>-<setting_id>\". Each entry sets one cloudflare_zone_setting; value is the string form (on/off, ssl mode, tls version)."
  type = map(object({
    zone_id    = string
    setting_id = string
    value      = string
  }))
  default = {}
}

variable "dnssec_zones" {
  description = "Map of logical zone name to DNSSEC config; status is forced active. multi_signer/presigned/use_nsec3 must mirror live or the zone re-signs (new DS record). Cloudflare Registrar submits the DS automatically; external registrars need the DS output registered by hand."
  type = map(object({
    zone_id      = string
    multi_signer = optional(bool)
    presigned    = optional(bool)
    use_nsec3    = optional(bool)
  }))
  default = {}
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone Settings + DNS read/write; sourced from the cloudflare-tokens dependency (token_values[\"zonecfg\"])."
  type        = string
  sensitive   = true
}
