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

locals {
  # --- split on who owns `content`. ignore_changes takes a static list and
  #     cannot be varied per for_each instance, so the two groups need
  #     separate resources. ---
  owned_records    = { for k, r in var.dns_records : k => r if !r.external_content }
  external_records = { for k, r in var.dns_records : k => r if r.external_content }
}

resource "cloudflare_dns_record" "records" {
  for_each = local.owned_records

  zone_id = each.value.zone_id
  name    = each.value.name
  content = each.value.content
  type    = each.value.type
  proxied = lookup(each.value, "proxied", true)
  ttl     = lookup(each.value, "ttl", 1)
}

# --- Records whose value is maintained at runtime. Terraform still owns that
#     the record exists and its name/type/proxied/ttl; only `content` is
#     conceded. `content` here seeds creation and is not reconciled after --
#     a literal in code cannot track an address that changes on its own, and
#     applying one over a live value takes the endpoint offline. ---
resource "cloudflare_dns_record" "external_records" {
  for_each = local.external_records

  zone_id = each.value.zone_id
  name    = each.value.name
  content = each.value.content
  type    = each.value.type
  proxied = lookup(each.value, "proxied", true)
  ttl     = lookup(each.value, "ttl", 1)

  lifecycle {
    ignore_changes = [content]
  }
}

# --- cloudflare v4 -> v5 rename; state migrates in place, no recreate ---
moved {
  from = cloudflare_record.records
  to   = cloudflare_dns_record.records
}

# --- wg moves to the external-content resource; state migrates in place so the
#     live record is not destroyed. Safe to drop once applied. ---
moved {
  from = cloudflare_dns_record.records["munchbox-wg"]
  to   = cloudflare_dns_record.external_records["munchbox-wg"]
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
          http_host_header         = lookup(rule.origin_request, "http_host_header", null)
          connect_timeout          = lookup(rule.origin_request, "connect_timeout", null)
          tls_timeout              = lookup(rule.origin_request, "tls_timeout", null)
          tcp_keep_alive           = lookup(rule.origin_request, "tcp_keep_alive", null)
          keep_alive_connections   = lookup(rule.origin_request, "keep_alive_connections", null)
          keep_alive_timeout       = lookup(rule.origin_request, "keep_alive_timeout", null)
          http2_origin             = lookup(rule.origin_request, "http2_origin", null)
          disable_chunked_encoding = lookup(rule.origin_request, "disable_chunked_encoding", null)
          no_happy_eyeballs        = lookup(rule.origin_request, "no_happy_eyeballs", null)
          no_tls_verify            = lookup(rule.origin_request, "no_tls_verify", null)
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
