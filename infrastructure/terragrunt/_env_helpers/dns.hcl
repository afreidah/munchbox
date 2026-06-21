# -----------------------------------------------------------------------------
# DNS ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the dns module. Public records are derived from the shared
# catalog (root.locals.web_services): a proxied CNAME -> tunnel for each public
# munchbox.cc service, and one per host for each alexfreidah.com service. There
# is NO wildcard -- deny-by-default; only catalogued public names resolve. The
# wg A-record is static. tunnel_config manages the cloudflared ingress via the
# dnsedge token; rate_limiting_rulesets stays disabled (token lacks Rulesets:Edit).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/dns"
}

dependency "cloudflare_tokens" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/cloudflare-tokens"

  mock_outputs = {
    token_values = { dnsedge = "mock-dnsedge-token" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  tunnel_cname        = local.root.locals.cloudflare_tunnel_cname
  munchbox_zone_id    = local.root.locals.cloudflare_munchbox_zone_id
  alexfreidah_zone_id = local.root.locals.cloudflare_alexfreidah_zone_id

  # --- origin defaults the tunnel API echoes back for the alexfreidah hosts ---
  af_origin = {
    connect_timeout          = 30
    tls_timeout              = 10
    tcp_keep_alive           = 30
    keep_alive_connections   = 100
    keep_alive_timeout       = 90
    http2_origin             = false
    disable_chunked_encoding = false
    no_happy_eyeballs        = false
    no_tls_verify            = false
  }

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

  tunnel_config = {
    account_id = local.root.locals.cloudflare_account_id
    tunnel_id  = local.root.locals.cloudflare_tunnel_id
    ingress_rules = [
      { hostname = "alexfreidah.com", service = "http://127.0.0.1:80", origin_request = merge(local.af_origin, { http_host_header = "alexfreidah.com" }) },
      { hostname = "www.alexfreidah.com", service = "http://127.0.0.1:80", origin_request = merge(local.af_origin, { http_host_header = "www.alexfreidah.com" }) },
      { hostname = "resume.alexfreidah.com", service = "http://127.0.0.1:80", origin_request = merge(local.af_origin, { http_host_header = "resume.alexfreidah.com" }) },
      { hostname = "k3s-status.alexfreidah.com", service = "http://127.0.0.1:80", origin_request = merge(local.af_origin, { http_host_header = "k3s-status.alexfreidah.com" }) },
      { hostname = "analytics.alexfreidah.com", service = "http://127.0.0.1:80", origin_request = merge(local.af_origin, { http_host_header = "analytics.alexfreidah.com" }) },
      { hostname = "*.munchbox.cc", service = "http://127.0.0.1:80" },
      { service = "http_status:404" },
    ]
  }

  cloudflare_api_token = dependency.cloudflare_tokens.outputs.token_values["dnsedge"]
}
