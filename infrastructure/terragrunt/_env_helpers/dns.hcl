# -----------------------------------------------------------------------------
# DNS ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the dns module. Public records are derived from the shared
# catalog (root.locals.web_services): a proxied CNAME -> tunnel for each public
# munchbox.cc service, and one per host for each alexfreidah.com service. There
# is NO wildcard -- deny-by-default; only catalogued public names resolve. The
# wg A-record is static. rate_limiting_rulesets + tunnel_config stay disabled
# (token scope / out-of-band tunnel ownership).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/dns"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  tunnel_cname        = local.root.locals.cloudflare_tunnel_cname
  munchbox_zone_id    = local.root.locals.cloudflare_munchbox_zone_id
  alexfreidah_zone_id = local.root.locals.cloudflare_alexfreidah_zone_id

  # --- munchbox.cc: static wg A-record (non-proxied, kept current by oracle-watchdog) ---
  munchbox_static = {
    "munchbox-wg" = {
      zone_id = local.munchbox_zone_id
      name    = "wg"
      type    = "A"
      content = "23.240.245.39"
      proxied = false
      ttl     = 60
    }
  }

  # --- proxied CNAME -> tunnel for each public munchbox.cc service ---
  munchbox_public_cnames = {
    for slug, svc in local.root.locals.web_services :
    "munchbox-${slug}" => {
      zone_id = local.munchbox_zone_id
      name    = slug
      type    = "CNAME"
      content = local.tunnel_cname
    }
    if try(svc.public, false) && try(svc.zone, "munchbox") == "munchbox"
  }

  # --- alexfreidah.com: public-only CNAME per host of each alexfreidah service.
  #     concat([{}], ...) keeps merge() valid if the list is ever empty. ---
  alexfreidah_cnames = merge(concat([{}], [
    for slug, svc in local.root.locals.web_services : {
      for h in try(svc.hosts, []) :
      "alexfreidah-${slug}-${h}" => {
        zone_id = local.alexfreidah_zone_id
        name    = h
        type    = "CNAME"
        content = local.tunnel_cname
      }
    } if try(svc.public, false) && try(svc.zone, "") == "alexfreidah"
  ])...)
}

inputs = {
  dns_records = merge(
    local.munchbox_static,
    local.munchbox_public_cnames,
    local.alexfreidah_cnames,
  )

  # --- disabled: CF token lacks Account:Rulesets:Edit ---
  rate_limiting_rulesets = {}

  # --- disabled: tunnel owned out-of-band by cloudflared sidecar ---
  tunnel_config = null
}
