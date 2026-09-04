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

variable "zone_settings_numeric" {
  description = "Same shape as zone_settings, for settings whose API value is a number (browser_cache_ttl). Kept separate because a single map would unify every value to string and the API rejects a quoted integer."
  type = map(object({
    zone_id    = string
    setting_id = string
    value      = number
  }))
  default = {}
}

# Cache Rules outrank browser_cache_ttl, so a rule left in the dashboard
# silently overrides the codified baseline. Modes are Cloudflare's:
# respect_origin (honour the origin's Cache-Control), override_origin (ignore
# it and use `default` seconds), bypass_by_default.
variable "cache_rulesets" {
  description = "Map of http_request_cache_settings rulesets, one per zone. Rules are evaluated in order and all use the set_cache_settings action."
  type = map(object({
    zone_id     = string
    name        = string
    description = optional(string, "")
    rules = list(object({
      expression  = string
      description = optional(string, "")
      enabled     = optional(bool, true)
      cache       = optional(bool, true)
      browser_ttl = object({
        mode    = string
        default = optional(number)
      })
      edge_ttl = object({
        mode    = string
        default = optional(number)
      })
    }))
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
