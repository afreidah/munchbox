# -----------------------------------------------------------------------------
# CLOUDFLARE WAF ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the cloudflare-waf module. Deploys the Cloudflare Managed WAF
# ruleset, Super Bot Fight Mode + AI bot controls and the custom rules on both
# Pro zones (munchbox.cc and alexfreidah.com). Provider auth is the scoped
# "wafbot" token pulled from the cloudflare-tokens leaf via dependency; the
# probe token comes from the passwords leaf. Apply both first. dependency
# outputs are referenced from inputs only.
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

dependency "passwords" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/passwords"

  mock_outputs = {
    vault_data = { "blackbox-exporter-external" = { probe_token = "mock-probe-token" } }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]

  # --- vault_data is in state, so a new entry is a missing nested key, not a
  #     missing output: deep-merge so it resolves to the mock until applied. ---
  mock_outputs_merge_strategy_with_state = "deep_map_only"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  mz   = local.root.locals.cloudflare_munchbox_zone_id
  az   = local.root.locals.cloudflare_alexfreidah_zone_id

  # --- blackbox-exporter-external probes from an Oracle node, which Cloudflare
  #     classes as automated and challenges. A request carrying its token skips
  #     the managed WAF and Super Bot Fight Mode; %s is the token. ---
  probe_skip = {
    description = "blackbox-exporter-external probe"
    action      = "skip"
    skip_phases = ["http_request_firewall_managed", "http_request_sbfm"]
  }
  probe_skip_expression = "any(http.request.headers[\"x-munchbox-probe\"][*] eq \"%s\")"
}

inputs = {
  cloudflare_api_token = dependency.cloudflare_tokens.outputs.token_values["wafbot"]

  # --- managed WAF ruleset: both zones are Pro ---
  managed_rules_zones = {
    alexfreidah = local.az
    munchbox    = local.mz
  }

  bot_management = {
    # --- munchbox.cc: Pro plan -> Super Bot Fight Mode + AI bot controls.
    #
    # The docs sites here exist to be indexed, so verified bots are pinned to
    # allow rather than left to the dashboard default; Googlebot takes that
    # path. definitely_automated is a challenge for the same reason as
    # alexfreidah.com below. ---
    munchbox = {
      zone_id                         = local.mz
      sbfm_definitely_automated       = "managed_challenge"
      sbfm_verified_bots              = "allow"
      sbfm_static_resource_protection = false
      optimize_wordpress              = false
      enable_js                       = true
      ai_bots_protection              = "block"
      crawler_protection              = "enabled"
    }
    # --- alexfreidah.com: Pro plan -> Super Bot Fight Mode + AI bot controls.
    #     "likely automated" tier is Business+ only, so it's intentionally unset.
    #
    # definitely_automated is a challenge rather than a block because SBFM
    # classifies on source IP, not user agent: a plain browser from any
    # datacenter or hosting ASN was getting a hard 403. Verified from an Oracle
    # node, where a normal Chrome UA was refused while the same request from a
    # residential IP succeeded. That catches corporate VPNs, egress proxies and
    # WARP -- and resume.alexfreidah.com exists to be read by strangers, often
    # from exactly those networks.
    #
    # managed_challenge still fails automation, which cannot solve the JS, but
    # lets a real browser through. Crawlers are unaffected either way; they take
    # the verified_bots path below. ---
    alexfreidah = {
      zone_id                         = local.az
      sbfm_definitely_automated       = "managed_challenge"
      sbfm_verified_bots              = "allow"
      sbfm_static_resource_protection = false
      optimize_wordpress              = false
      enable_js                       = true
      ai_bots_protection              = "block"
      crawler_protection              = "enabled"
    }
  }

  # --- custom rules, in order. alexfreidah.com's entrypoint was made in the
  #     dashboard and is imported, so its country challenge is listed here, first
  #     and verbatim, to be kept as is; the probe never matches it. ---
  custom_rules = {
    alexfreidah = {
      zone_id = local.az
      rules = [
        {
          description = "No-Russian-Pricks"
          expression  = "(ip.src.country eq \"RU\") or (ip.src.country eq \"BY\") or (ip.src.country eq \"CN\") or (ip.src.country eq \"IR\")"
          action      = "managed_challenge"
        },
        merge(local.probe_skip, {
          expression = format(local.probe_skip_expression, dependency.passwords.outputs.vault_data["blackbox-exporter-external"].probe_token)
        }),
      ]
    }
    munchbox = {
      zone_id = local.mz
      rules = [
        merge(local.probe_skip, {
          expression = format(local.probe_skip_expression, dependency.passwords.outputs.vault_data["blackbox-exporter-external"].probe_token)
        }),
      ]
    }
  }
}
