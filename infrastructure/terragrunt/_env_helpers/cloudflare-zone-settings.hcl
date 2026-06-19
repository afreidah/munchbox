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
  config_path = "${get_repo_root()}/infrastructure/terragrunt/global/secrets/cloudflare-tokens"

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
  }

  # --- flatten zones x baseline into the module's keyed map ---
  zone_settings = merge([
    for zkey, zid in local.zones : {
      for sid, val in local.baseline :
      "${zkey}-${sid}" => { zone_id = zid, setting_id = sid, value = val }
    }
  ]...)

  dnssec_zones = {
    munchbox    = { zone_id = local.zones.munchbox }
    alexfreidah = { zone_id = local.zones.alexfreidah, multi_signer = true }
  }
}

inputs = {
  zone_settings        = local.zone_settings
  dnssec_zones         = local.dnssec_zones
  cloudflare_api_token = dependency.cloudflare_tokens.outputs.token_values["zonecfg"]
}
