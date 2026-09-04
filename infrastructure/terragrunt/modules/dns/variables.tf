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
  description = "Map of DNS records to create. Set external_content on records whose value is maintained at runtime by something outside terraform; content then seeds creation only and drift on it is ignored."
  type = map(object({
    zone_id          = string
    name             = string
    content          = string
    type             = string
    proxied          = optional(bool, true)
    ttl              = optional(number, 1)
    external_content = optional(bool, false)
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
        http_host_header         = optional(string)
        connect_timeout          = optional(number)
        tls_timeout              = optional(number)
        tcp_keep_alive           = optional(number)
        keep_alive_connections   = optional(number)
        keep_alive_timeout       = optional(number)
        http2_origin             = optional(bool)
        disable_chunked_encoding = optional(bool)
        no_happy_eyeballs        = optional(bool)
        no_tls_verify            = optional(bool)
      }))
    }))
  })
  default = null
}

# -----------------------------------------------------------------------------
# PROVIDER AUTH
# -----------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare API token (DNS + Tunnel scope); sourced from the cloudflare-tokens dependency (token_values[\"dnsedge\"])."
  type        = string
  sensitive   = true
}
