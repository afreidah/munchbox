# -----------------------------------------------------------------------------
# cloudflare-waf module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the managed-ruleset fan-out (one per managed_rules_zones entry), the
# bot-management fan-out (one per bot_management entry), the custom-rules
# entrypoint and its rule rendering, and that empty maps produce no resources.
# -----------------------------------------------------------------------------

mock_provider "cloudflare" {}

variables {
  cloudflare_api_token = "mock-token"

  managed_rules_zones = {
    alexfreidah = "00000000000000000000000000000001"
  }

  bot_management = {
    munchbox = {
      zone_id            = "00000000000000000000000000000002"
      fight_mode         = true
      ai_bots_protection = "block"
    }
    alexfreidah = {
      zone_id                   = "00000000000000000000000000000001"
      sbfm_definitely_automated = "block"
      sbfm_likely_automated     = "managed_challenge"
      sbfm_verified_bots        = "allow"
    }
  }
}

# -------------------------------------------------------------------------
# fan-out
# -------------------------------------------------------------------------

run "fan_out" {
  command = plan

  assert {
    condition     = length(cloudflare_ruleset.managed) == 1
    error_message = "one managed_rules_zones entry -> one managed ruleset"
  }

  assert {
    condition     = length(cloudflare_bot_management.this) == 2
    error_message = "two bot_management entries -> two bot management resources"
  }

  # --- managed_ruleset_ids keyed by every managed_rules_zones entry (id computed) ---
  assert {
    condition     = toset(keys(output.managed_ruleset_ids)) == toset(["alexfreidah"])
    error_message = "managed_ruleset_ids must be keyed by every managed_rules_zones entry"
  }

  # --- bot_management_zones lists every configured zone ---
  assert {
    condition     = toset(output.bot_management_zones) == toset(["munchbox", "alexfreidah"])
    error_message = "bot_management_zones must list every configured zone"
  }
}

# -------------------------------------------------------------------------
# custom rules: one entrypoint per zone, skip rules carry their phases
# -------------------------------------------------------------------------

run "custom_rules" {
  command = plan

  variables {
    custom_rules = {
      alexfreidah = {
        zone_id = "00000000000000000000000000000001"
        rules = [
          {
            description = "probe bypass"
            expression  = "any(http.request.headers[\"x-probe\"][*] eq \"t\")"
            action      = "skip"
            skip_phases = ["http_request_firewall_managed", "http_request_sbfm"]
          },
          {
            description = "geo challenge"
            expression  = "(ip.src.country in {\"RU\"})"
            action      = "managed_challenge"
          },
        ]
      }
    }
  }

  # --- the mocked zone has no custom-rules entrypoint, so the ruleset is created.
  #     The import path is not covered here: mocked data cannot populate the
  #     rulesets set, so it is exercised by planning the waf leaf. ---
  assert {
    condition     = length(cloudflare_ruleset.custom) == 1
    error_message = "one custom_rules entry -> one custom-rules entrypoint"
  }

  assert {
    condition     = cloudflare_ruleset.custom["alexfreidah"].phase == "http_request_firewall_custom"
    error_message = "custom rules belong to the http_request_firewall_custom phase"
  }

  # --- rules keep their order; a skip rule skips its phases and logs matches ---
  assert {
    condition = (
      cloudflare_ruleset.custom["alexfreidah"].rules[0].action == "skip"
      && toset(cloudflare_ruleset.custom["alexfreidah"].rules[0].action_parameters.phases) == toset(["http_request_firewall_managed", "http_request_sbfm"])
      && cloudflare_ruleset.custom["alexfreidah"].rules[0].logging.enabled
    )
    error_message = "the skip rule must come first, skip its phases and log matches"
  }

  assert {
    condition     = cloudflare_ruleset.custom["alexfreidah"].rules[1].action == "managed_challenge"
    error_message = "the second rule must keep its own action"
  }

  # --- custom_ruleset_ids keyed by every custom_rules entry (id computed) ---
  assert {
    condition     = toset(keys(output.custom_ruleset_ids)) == toset(["alexfreidah"])
    error_message = "custom_ruleset_ids must be keyed by every custom_rules entry"
  }
}

# -------------------------------------------------------------------------
# empty maps create nothing
# -------------------------------------------------------------------------

run "empty" {
  command = plan

  variables {
    managed_rules_zones = {}
    bot_management      = {}
  }

  assert {
    condition     = length(cloudflare_ruleset.managed) == 0 && length(cloudflare_bot_management.this) == 0 && length(cloudflare_ruleset.custom) == 0
    error_message = "empty maps -> no resources"
  }

  # --- outputs are empty collections when nothing is configured ---
  assert {
    condition     = length(output.managed_ruleset_ids) == 0 && length(output.bot_management_zones) == 0 && length(output.custom_ruleset_ids) == 0
    error_message = "empty maps -> empty outputs"
  }
}
