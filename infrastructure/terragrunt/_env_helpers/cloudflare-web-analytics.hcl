# -----------------------------------------------------------------------------
# CLOUDFLARE WEB ANALYTICS ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the cloudflare-web-analytics module. Enables Web Analytics
# (RUM) on the selected zones so the rum* GraphQL datasets populate for the
# cloudflare-log-collector. The provider authenticates with the scoped
# "webanalytics" token minted by the cloudflare-tokens leaf (Account Settings
# read/write), pulled in as a dependency -- so the bootstrap CLOUDFLARE_API_TOKEN
# stays narrow. Apply the cloudflare-tokens leaf first so the token exists.
# Enabling is not retroactive; RUM collection starts going forward.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//cloudflare-web-analytics"
}

dependency "cloudflare_tokens" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/cloudflare-tokens"

  mock_outputs = {
    token_values = { webanalytics = "mock-webanalytics-token" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  # --- RUM sites: auto_install injects the beacon for these orange-clouded
  # (proxied) zones, so no site code change is needed. ---
  sites = {
    munchbox = {
      zone_tag     = local.root.locals.cloudflare_munchbox_zone_id
      auto_install = true
      enabled      = true
    }
    alexfreidah = {
      zone_tag     = local.root.locals.cloudflare_alexfreidah_zone_id
      auto_install = true
      enabled      = true
    }
  }
}

inputs = {
  account_id           = local.root.locals.cloudflare_account_id
  sites                = local.sites
  cloudflare_api_token = dependency.cloudflare_tokens.outputs.token_values["webanalytics"]
}
