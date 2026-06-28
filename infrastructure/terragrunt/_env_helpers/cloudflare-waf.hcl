# -----------------------------------------------------------------------------
# CLOUDFLARE WAF ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the cloudflare-waf module. Deploys the Cloudflare Managed WAF
# ruleset on the Pro zone (alexfreidah.com) and per-zone bot management:
# munchbox.cc (free) gets Bot Fight Mode + AI bot controls; alexfreidah.com (Pro)
# gets Super Bot Fight Mode + AI bot controls. Provider auth is the scoped
# "wafbot" token pulled from the cloudflare-tokens leaf via dependency; apply
# that leaf first. dependency outputs are referenced from inputs only.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//cloudflare-waf"
}

dependency "cloudflare_tokens" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/cloudflare-tokens"

  mock_outputs = {
    token_values = { wafbot = "mock-wafbot-token" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  mz   = local.root.locals.cloudflare_munchbox_zone_id
  az   = local.root.locals.cloudflare_alexfreidah_zone_id
}

inputs = {
  cloudflare_api_token = dependency.cloudflare_tokens.outputs.token_values["wafbot"]

  # --- managed WAF ruleset: Pro zone only (free can't deploy the full ruleset) ---
  managed_rules_zones = {
    alexfreidah = local.az
  }

  bot_management = {
    # --- munchbox.cc: Free plan -> Bot Fight Mode (requires JS detections) + AI ---
    munchbox = {
      zone_id            = local.mz
      fight_mode         = true
      enable_js          = true
      ai_bots_protection = "block"
      crawler_protection = "enabled"
    }
    # --- alexfreidah.com: Pro plan -> Super Bot Fight Mode + AI bot controls.
    #     "likely automated" tier is Business+ only, so it's intentionally unset. ---
    alexfreidah = {
      zone_id                         = local.az
      sbfm_definitely_automated       = "block"
      sbfm_verified_bots              = "allow"
      sbfm_static_resource_protection = false
      optimize_wordpress              = false
      enable_js                       = true
      ai_bots_protection              = "block"
      crawler_protection              = "enabled"
    }
  }
}
