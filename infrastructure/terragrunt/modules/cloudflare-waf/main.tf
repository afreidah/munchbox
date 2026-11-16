# -----------------------------------------------------------------------------
# CLOUDFLARE-WAF MODULE
# -----------------------------------------------------------------------------
#
# Deploys the Cloudflare Managed WAF ruleset, per-zone bot management and per-zone
# custom rules. Generic over zones -- the caller supplies the maps; this module
# fans out with for_each.
# Bot config is plan-tier sensitive (free => fight_mode, Pro => sbfm_*), so each
# zone only sets the fields valid for its plan.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# MANAGED WAF RULESET
# -----------------------------------------------------------------------------
# Entrypoint ruleset that executes the Cloudflare Managed Ruleset
# (id efb7b8c949ac4650a09736fc376e9aee) on all traffic. Pro+ zones only.

resource "cloudflare_ruleset" "managed" {
  for_each = var.managed_rules_zones

  zone_id = each.value
  name    = "managed-waf"
  kind    = "zone"
  phase   = "http_request_firewall_managed"

  rules = [{
    action      = "execute"
    expression  = "true"
    description = "Deploy Cloudflare Managed Ruleset"
    enabled     = true
    action_parameters = {
      id = "efb7b8c949ac4650a09736fc376e9aee"
    }
  }]
}

# -----------------------------------------------------------------------------
# BOT MANAGEMENT
# -----------------------------------------------------------------------------
# One resource per zone; unset (null) optional fields are omitted so a free zone
# can pass only fight_mode without tripping Pro-only validation.

resource "cloudflare_bot_management" "this" {
  for_each = var.bot_management

  zone_id                         = each.value.zone_id
  fight_mode                      = each.value.fight_mode
  sbfm_definitely_automated       = each.value.sbfm_definitely_automated
  sbfm_likely_automated           = each.value.sbfm_likely_automated
  sbfm_verified_bots              = each.value.sbfm_verified_bots
  sbfm_static_resource_protection = each.value.sbfm_static_resource_protection
  optimize_wordpress              = each.value.optimize_wordpress
  suppress_session_score          = each.value.suppress_session_score
  ai_bots_protection              = each.value.ai_bots_protection
  crawler_protection              = each.value.crawler_protection
  enable_js                       = each.value.enable_js
}

# -----------------------------------------------------------------------------
# CUSTOM RULES
# -----------------------------------------------------------------------------
# One http_request_firewall_custom entrypoint per zone. A zone holds a single
# entrypoint per phase, so one that already exists is imported rather than
# created beside it; cloudflare_rulesets finds it by phase. A skip rule logs its
# matches, so every bypass still shows in the firewall events.

data "cloudflare_rulesets" "custom" {
  for_each = var.custom_rules

  zone_id = each.value.zone_id
}

locals {
  custom_entrypoints = {
    for k, d in data.cloudflare_rulesets.custom : k => one([
      for rs in d.rulesets : rs.id if rs.kind == "zone" && rs.phase == "http_request_firewall_custom"
    ])
  }
}

import {
  for_each = { for k, id in local.custom_entrypoints : k => id if id != null }

  to = cloudflare_ruleset.custom[each.key]
  id = "zones/${var.custom_rules[each.key].zone_id}/${each.value}"
}

resource "cloudflare_ruleset" "custom" {
  for_each = var.custom_rules

  zone_id = each.value.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules = [for r in each.value.rules : {
    action            = r.action
    expression        = r.expression
    description       = r.description
    enabled           = true
    action_parameters = r.skip_phases == null ? null : { phases = r.skip_phases }
    logging           = r.action == "skip" ? { enabled = true } : null
  }]
}
