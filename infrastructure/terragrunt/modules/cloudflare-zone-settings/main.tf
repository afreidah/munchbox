# -----------------------------------------------------------------------------
# CLOUDFLARE-ZONE-SETTINGS MODULE
# -----------------------------------------------------------------------------
#
# Codifies zone-level security/TLS baseline and DNSSEC for Cloudflare zones.
# Each cloudflare_zone_setting owns one setting on one zone (the provider has
# no bulk resource), so callers pass a flat map. cloudflare_zone_setting always
# overwrites the live value, and DNSSEC requires the emitted DS record to be
# registered at the registrar before signing goes active.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ZONE SETTINGS
# -----------------------------------------------------------------------------

resource "cloudflare_zone_setting" "this" {
  for_each = var.zone_settings

  zone_id    = each.value.zone_id
  setting_id = each.value.setting_id
  value      = each.value.value
}

# --- Numeric-valued settings. Same resource, separate map: the string map
#     would coerce 0 to "0" and the API rejects it. ---
resource "cloudflare_zone_setting" "numeric" {
  for_each = var.zone_settings_numeric

  zone_id    = each.value.zone_id
  setting_id = each.value.setting_id
  value      = each.value.value
}

# -----------------------------------------------------------------------------
# CACHE RULESETS
# -----------------------------------------------------------------------------

resource "cloudflare_ruleset" "cache" {
  for_each = var.cache_rulesets

  zone_id     = each.value.zone_id
  name        = each.value.name
  description = each.value.description
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules = [
    for rule in each.value.rules : {
      action      = "set_cache_settings"
      expression  = rule.expression
      description = rule.description
      enabled     = rule.enabled

      action_parameters = {
        cache       = rule.cache
        browser_ttl = rule.browser_ttl
        edge_ttl    = rule.edge_ttl
      }
    }
  ]
}

# -----------------------------------------------------------------------------
# DNSSEC
# -----------------------------------------------------------------------------

resource "cloudflare_zone_dnssec" "this" {
  for_each = var.dnssec_zones

  zone_id             = each.value.zone_id
  status              = "active"
  dnssec_multi_signer = each.value.multi_signer
  dnssec_presigned    = each.value.presigned
  dnssec_use_nsec3    = each.value.use_nsec3
}
