# -----------------------------------------------------------------------------
# CLOUDFLARE-WEB-ANALYTICS MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "account_id" {
  description = "Cloudflare account identifier that owns the Web Analytics (RUM) sites. cloudflare_web_analytics_site is account-scoped even though each site references a zone."
  type        = string
}

variable "sites" {
  description = "Map of logical zone name to Web Analytics (RUM) site config. auto_install injects the JS beacon for orange-clouded (proxied) zones via zone_tag; enabled turns RUM on and is only valid when auto_install is true. Use host (gray-clouded sites) when the beacon must be embedded manually from the snippet output. lite drops the beacon for EU visitors."
  type = map(object({
    zone_tag     = optional(string)
    auto_install = optional(bool, true)
    enabled      = optional(bool, true)
    host         = optional(string)
    lite         = optional(bool)
  }))
  default = {}
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Account Settings Read + Write; sourced from the cloudflare-tokens dependency (token_values[\"webanalytics\"])."
  type        = string
  sensitive   = true
}
