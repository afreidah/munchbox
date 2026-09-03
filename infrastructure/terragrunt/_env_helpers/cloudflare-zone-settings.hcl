# -----------------------------------------------------------------------------
# CLOUDFLARE ZONE SETTINGS ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the cloudflare-zone-settings module. Applies one security/TLS
# baseline to every managed zone (munchbox.cc + alexfreidah.com) and sets DNSSEC
# active on both. The provider authenticates with the scoped "zonecfg" token
# minted by the cloudflare-tokens leaf (Zone Settings + DNS read/write), pulled
# in as a dependency -- so the bootstrap CLOUDFLARE_API_TOKEN stays narrow. Apply
# the cloudflare-tokens leaf first so the token exists. cloudflare_zone_setting
# overwrites the live value; HSTS (security_header) is intentionally omitted --
# it is sticky in browsers and belongs in its own deliberate change.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//cloudflare-zone-settings"
}

dependency "cloudflare_tokens" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/cloudflare-tokens"

  mock_outputs = {
    token_values = { zonecfg = "mock-zonecfg-token" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  zones = {
    munchbox    = local.root.locals.cloudflare_munchbox_zone_id
    alexfreidah = local.root.locals.cloudflare_alexfreidah_zone_id
  }

  # --- security/TLS baseline applied to every managed zone ---
  baseline = {
    ssl                      = "strict"
    min_tls_version          = "1.2"
    always_use_https         = "on"
    automatic_https_rewrites = "on"
    tls_1_3                  = "on"
    opportunistic_encryption = "on"
    brotli                   = "on"

    # --- hygiene toggles (default-on; codified so they can't silently drift) ---
    browser_check     = "on"
    email_obfuscation = "on"
    websockets        = "on"
    http3             = "on"

    # --- opt-in performance (deliberate enable) ---
    early_hints = "on"

    # --- serve a cached snapshot when the origin is unreachable ---
    always_online = "on"
  }

  # --- numeric-valued settings; separate map because the string one would
  #     quote the integer and the API rejects that ---
  #
  # browser_cache_ttl 0 = "Respect Existing Headers". Cloudflare's default is
  # 14400, and it overwrites whatever the origin sent on the way out -- so
  # nginx's `no-cache` on html became `max-age=14400` and every deploy pinned
  # the previous page in every visitor's browser for four hours. The origin
  # already sets this correctly per content type; let it through.
  baseline_numeric = {
    browser_cache_ttl = 0
  }

  # --- flatten zones x baseline into the module's keyed map ---
  zone_settings = merge([
    for zkey, zid in local.zones : {
      for sid, val in local.baseline :
      "${zkey}-${sid}" => { zone_id = zid, setting_id = sid, value = val }
    }
  ]...)

  zone_settings_numeric = merge([
    for zkey, zid in local.zones : {
      for sid, val in local.baseline_numeric :
      "${zkey}-${sid}" => { zone_id = zid, setting_id = sid, value = val }
    }
  ]...)

  # --- Cache Rules. These outrank browser_cache_ttl above, so anything set
  #     here wins; codified so a dashboard edit can't quietly override the
  #     baseline again.
  #
  # The s3-orchestrator rule was override_origin 14400 browser / 86400 edge,
  # which ignored the origin entirely: nginx's `no-cache` on html became a 4h
  # browser pin, and the edge served day-old html. respect_origin hands the
  # decision back to nginx, which already sets it per content type (no-cache
  # for html, 1y for hashed assets). cache stays true so those assets are
  # still edge-cacheable on their own headers. ---
  cache_rulesets = {
    munchbox = {
      zone_id = local.zones.munchbox
      name    = "default"
      rules = [{
        description = "s3-orchestrator"
        expression  = "(http.request.full_uri contains \"s3-orchestrator.munchbox.cc\")"
        cache       = true
        browser_ttl = { mode = "respect_origin" }
        edge_ttl    = { mode = "respect_origin" }
      }]
    }
  }

  dnssec_zones = {
    munchbox    = { zone_id = local.zones.munchbox }
    alexfreidah = { zone_id = local.zones.alexfreidah, multi_signer = true }
  }
}

inputs = {
  zone_settings         = local.zone_settings
  zone_settings_numeric = local.zone_settings_numeric
  cache_rulesets        = local.cache_rulesets
  dnssec_zones          = local.dnssec_zones
  cloudflare_api_token  = dependency.cloudflare_tokens.outputs.token_values["zonecfg"]
}
