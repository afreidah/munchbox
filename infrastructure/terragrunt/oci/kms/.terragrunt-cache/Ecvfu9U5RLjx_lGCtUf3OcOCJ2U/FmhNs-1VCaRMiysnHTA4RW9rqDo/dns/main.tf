# -----------------------------------------------------------------------------
# DNS MODULE
# -----------------------------------------------------------------------------
#
# Generic Cloudflare DNS management module. Creates DNS records, configures
# tunnel ingress routing, and applies rate limiting rules based on input
# configuration.
#
# Components Created:
#   - Cloudflare DNS records (configurable type, proxied status)
#   - WAF rate limiting rulesets
#   - Tunnel ingress configuration
#
# Architecture:
#   - Records and rules defined via input variables
#   - Supports multiple zones and record types
#   - Tunnel ingress rules applied in order with required catch-all
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DNS RECORDS
# -----------------------------------------------------------------------------

resource "cloudflare_record" "records" {
  for_each = var.dns_records

  zone_id = each.value.zone_id
  name    = each.value.name
  content = each.value.content
  type    = each.value.type
  proxied = lookup(each.value, "proxied", true)
  ttl     = lookup(each.value, "ttl", 1)
}

# -----------------------------------------------------------------------------
# RATE LIMITING RULESETS
# -----------------------------------------------------------------------------

resource "cloudflare_ruleset" "rate_limiting" {
  for_each = var.rate_limiting_rulesets

  zone_id     = each.value.zone_id
  name        = each.value.name
  description = lookup(each.value, "description", "")
  kind        = "zone"
  phase       = "http_ratelimit"

  dynamic "rules" {
    for_each = each.value.rules
    content {
      action      = rules.value.action
      expression  = rules.value.expression
      description = lookup(rules.value, "description", "")
      enabled     = lookup(rules.value, "enabled", true)

      ratelimit {
        characteristics     = rules.value.characteristics
        period              = rules.value.period
        requests_per_period = rules.value.requests_per_period
        mitigation_timeout  = rules.value.mitigation_timeout
      }
    }
  }
}

# -----------------------------------------------------------------------------
# TUNNEL CONFIGURATION
# -----------------------------------------------------------------------------

resource "cloudflare_tunnel_config" "tunnel" {
  count = var.tunnel_config != null ? 1 : 0

  account_id = var.tunnel_config.account_id
  tunnel_id  = var.tunnel_config.tunnel_id

  config {
    dynamic "ingress_rule" {
      for_each = var.tunnel_config.ingress_rules
      content {
        hostname = lookup(ingress_rule.value, "hostname", null)
        service  = ingress_rule.value.service

        dynamic "origin_request" {
          for_each = lookup(ingress_rule.value, "origin_request", null) != null ? [ingress_rule.value.origin_request] : []
          content {
            http_host_header = lookup(origin_request.value, "http_host_header", null)
          }
        }
      }
    }
  }
}
