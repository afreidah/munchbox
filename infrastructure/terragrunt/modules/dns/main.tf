# -----------------------------------------------------------------------------
# DNS MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Generic Cloudflare DNS management: DNS records, optional tunnel ingress
# config, optional rate-limiting rulesets. Resource types and ruleset schema
# follow cloudflare provider v5.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DNS RECORDS
# -----------------------------------------------------------------------------

resource "cloudflare_dns_record" "records" {
  for_each = var.dns_records

  zone_id = each.value.zone_id
  name    = each.value.name
  content = each.value.content
  type    = each.value.type
  proxied = lookup(each.value, "proxied", true)
  ttl     = lookup(each.value, "ttl", 1)
}

# --- cloudflare v4 -> v5 rename; state migrates in place, no recreate ---
moved {
  from = cloudflare_record.records
  to   = cloudflare_dns_record.records
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

  rules = [
    for rule in each.value.rules : {
      action      = rule.action
      expression  = rule.expression
      description = lookup(rule, "description", "")
      enabled     = lookup(rule, "enabled", true)

      ratelimit = {
        characteristics     = rule.characteristics
        period              = rule.period
        requests_per_period = rule.requests_per_period
        mitigation_timeout  = rule.mitigation_timeout
      }
    }
  ]
}

# -----------------------------------------------------------------------------
# TUNNEL CONFIGURATION
# -----------------------------------------------------------------------------

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel" {
  count = var.tunnel_config != null ? 1 : 0

  account_id = var.tunnel_config.account_id
  tunnel_id  = var.tunnel_config.tunnel_id

  config = {
    ingress = [
      for rule in var.tunnel_config.ingress_rules : {
        hostname = lookup(rule, "hostname", null)
        service  = rule.service
        origin_request = lookup(rule, "origin_request", null) != null ? {
          http_host_header = lookup(rule.origin_request, "http_host_header", null)
        } : null
      }
    ]
  }
}

# --- cloudflare v4 -> v5 rename; state migrates in place, no recreate ---
moved {
  from = cloudflare_tunnel_config.tunnel
  to   = cloudflare_zero_trust_tunnel_cloudflared_config.tunnel
}
