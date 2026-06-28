# -----------------------------------------------------------------------------
# CLOUDFLARE-WAF MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare token with Zone WAF + Bot Management + Firewall for AI write; from the cloudflare-tokens dependency (token_values[\"wafbot\"])."
  type        = string
  sensitive   = true
}

variable "managed_rules_zones" {
  description = "Zones (logical name => zone_id) to deploy the Cloudflare Managed WAF ruleset on. Pro+ only."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# BOT MANAGEMENT
# -----------------------------------------------------------------------------
# Per-zone bot config. Plan-tier sensitive: free zones use fight_mode; Pro zones
# use the sbfm_* fields. Only set fields valid for the zone's plan; unset
# (null) fields are omitted.

variable "bot_management" {
  description = "Per-zone bot management config, keyed by logical zone name."
  type = map(object({
    zone_id                         = string
    fight_mode                      = optional(bool)   # free: Bot Fight Mode
    sbfm_definitely_automated       = optional(string) # pro: block | managed | allow
    sbfm_likely_automated           = optional(string) # pro
    sbfm_verified_bots              = optional(string) # pro: allow | block
    sbfm_static_resource_protection = optional(bool)   # pro
    optimize_wordpress              = optional(bool)   # pro
    suppress_session_score          = optional(bool)   # pro
    ai_bots_protection              = optional(string) # block | disabled
    crawler_protection              = optional(string) # enabled | disabled
    enable_js                       = optional(bool)
  }))
  default = {}
}
