# -----------------------------------------------------------------------------
# DNS MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Variable Categories:
#   - Records: DNS record definitions
#   - Rate Limiting: WAF rate limiting rulesets
#   - Tunnel: Cloudflare tunnel ingress configuration
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DNS RECORDS
# -----------------------------------------------------------------------------

variable "dns_records" {
  description = "Map of DNS records to create"
  type = map(object({
    zone_id = string
    name    = string
    content = string
    type    = string
    proxied = optional(bool, true)
    ttl     = optional(number, 1)
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# RATE LIMITING
# -----------------------------------------------------------------------------

variable "rate_limiting_rulesets" {
  description = "Map of rate limiting rulesets to create"
  type = map(object({
    zone_id     = string
    name        = string
    description = optional(string, "")
    rules = list(object({
      action              = string
      expression          = string
      description         = optional(string, "")
      enabled             = optional(bool, true)
      characteristics     = list(string)
      period              = number
      requests_per_period = number
      mitigation_timeout  = number
    }))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# TUNNEL CONFIGURATION
# -----------------------------------------------------------------------------

variable "tunnel_config" {
  description = "Cloudflare tunnel configuration with ingress rules"
  type = object({
    account_id = string
    tunnel_id  = string
    ingress_rules = list(object({
      hostname = optional(string)
      service  = string
      origin_request = optional(object({
        http_host_header = optional(string)
      }))
    }))
  })
  default = null
}
