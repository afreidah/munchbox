# -----------------------------------------------------------------------------
# cloudflare-waf module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the managed-ruleset fan-out (one per managed_rules_zones entry) and the
# bot-management fan-out (one per bot_management entry), and that empty maps
# produce no resources.
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
# empty maps create nothing
# -------------------------------------------------------------------------

run "empty" {
  command = plan

  variables {
    managed_rules_zones = {}
    bot_management      = {}
  }

  assert {
    condition     = length(cloudflare_ruleset.managed) == 0 && length(cloudflare_bot_management.this) == 0
    error_message = "empty maps -> no resources"
  }

  # --- outputs are empty collections when nothing is configured ---
  assert {
    condition     = length(output.managed_ruleset_ids) == 0 && length(output.bot_management_zones) == 0
    error_message = "empty maps -> empty outputs"
  }
}
