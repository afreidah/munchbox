# -----------------------------------------------------------------------------
# DNS ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the dns module. root.hcl holds the static cloudflare data;
# this helper stamps zone_id onto each record and merges the two zones.
# rate_limiting_rulesets + tunnel_config are intentionally disabled here
# (token scope / out-of-band tunnel ownership).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/dns"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  alexfreidah_records = {
    for k, n in local.root.locals.alexfreidah_tunnel_cnames :
    k => {
      zone_id = local.root.locals.cloudflare_alexfreidah_zone_id
      name    = n
      content = local.root.locals.cloudflare_tunnel_cname
      type    = "CNAME"
    }
  }

  munchbox_records = {
    for k, r in local.root.locals.munchbox_zone_records :
    k => merge(r, { zone_id = local.root.locals.cloudflare_munchbox_zone_id })
  }
}

inputs = {
  dns_records = merge(local.alexfreidah_records, local.munchbox_records)

  # --- disabled: CF token lacks Account:Rulesets:Edit ---
  rate_limiting_rulesets = {}

  # --- disabled: tunnel owned out-of-band by cloudflared sidecar ---
  tunnel_config = null
}
