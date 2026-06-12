# -----------------------------------------------------------------------------
# DNS ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the dns module. The record maps live here (zone/tunnel ids
# come from root.hcl); this helper stamps zone_id onto each record and merges
# the two zones. rate_limiting_rulesets + tunnel_config are intentionally
# disabled here (token scope / out-of-band tunnel ownership).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/dns"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  # --- alexfreidah-zone CNAMEs to the tunnel; map key = TF state key ---
  alexfreidah_tunnel_cnames = {
    "alexfreidah-apex"       = "@"
    "alexfreidah-www"        = "www"
    "alexfreidah-resume"     = "resume"
    "alexfreidah-resume-www" = "www.resume"
    "alexfreidah-k3s-status" = "k3s-status"
    "alexfreidah-analytics"  = "analytics"
  }

  # --- munchbox-zone records; wg = non-proxied A, kept current by oracle-watchdog ---
  munchbox_zone_records = {
    "munchbox-wildcard" = {
      name    = "*"
      type    = "CNAME"
      content = local.root.locals.cloudflare_tunnel_cname
    }
    "munchbox-wg" = {
      name    = "wg"
      type    = "A"
      content = "23.240.245.39"
      proxied = false
      ttl     = 60
    }
  }

  alexfreidah_records = {
    for k, n in local.alexfreidah_tunnel_cnames :
    k => {
      zone_id = local.root.locals.cloudflare_alexfreidah_zone_id
      name    = n
      content = local.root.locals.cloudflare_tunnel_cname
      type    = "CNAME"
    }
  }

  munchbox_records = {
    for k, r in local.munchbox_zone_records :
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
