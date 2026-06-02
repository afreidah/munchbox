# -----------------------------------------------------------------------------
# CLOUDFLARE-API-TOKEN MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "tokens" {
  description = "Map of token requests keyed by logical name. Each policy names permission groups by Cloudflare display name (resolved to IDs in-module) and scopes them to a resources map, e.g. { \"com.cloudflare.api.account.zone.<zone_id>\" = \"*\" }."
  type = map(object({
    name = string
    policies = list(object({
      effect            = optional(string, "allow")
      permission_groups = list(string)
      resources         = map(string)
    }))
    expires_on = optional(string)
  }))
}
