# -----------------------------------------------------------------------------
# PI-HOLE DNS ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the pihole-dns module. munchbox.cc service records come from
# the shared catalog (root.locals.web_services) expanded to A-records at the
# traefik VIP; node records (pihole_special_dns_records) + traefik_vip live
# here. pihole_primary/secondary_url come from root.hcl.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/pihole-dns"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  traefik_vip = "192.168.68.50"

  # --- hosts reached directly by ip ---
  pihole_special_dns_records = {
    "goren"           = { domain = "goren.munchbox.cc", ip = "192.168.68.60" }
    "stabler"         = { domain = "stabler.munchbox.cc", ip = "192.168.68.61" }
    "nomad-server-03" = { domain = "nomad-server-03.munchbox.cc", ip = "192.168.68.58" }
    "cabot"           = { domain = "cabot.munchbox.cc", ip = "192.168.68.59" }
    "mccoy"           = { domain = "mccoy.munchbox.cc", ip = "192.168.68.63" }
    "fontana"         = { domain = "fontana.munchbox.cc", ip = "192.168.68.65" }
    "rubirosa"        = { domain = "rubirosa.munchbox.cc", ip = "192.168.68.69" }
    "nomad-client-01" = { domain = "nomad-client-01.munchbox.cc", ip = "192.168.68.67" }
    "nomad-client-02" = { domain = "nomad-client-02.munchbox.cc", ip = "192.168.68.72" }
    "nomad-client-03" = { domain = "nomad-client-03.munchbox.cc", ip = "192.168.68.71" }
    "nomad-client-04" = { domain = "nomad-client-04.munchbox.cc", ip = "192.168.68.73" }
    "nomad-client-05" = { domain = "nomad-client-05.munchbox.cc", ip = "192.168.68.74" }
    "oracle-node-1"   = { domain = "oracle-node-1.munchbox.cc", ip = "10.200.0.11" }
    "oracle-node-2"   = { domain = "oracle-node-2.munchbox.cc", ip = "10.200.0.12" }
    "oracle-arm-1"    = { domain = "oracle-arm-1.munchbox.cc", ip = "10.200.0.13" }
    "oracle-arm-2"    = { domain = "oracle-arm-2.munchbox.cc", ip = "10.200.0.14" }
    "cinc-server"     = { domain = "cinc-server.munchbox.cc", ip = "192.168.68.99" }

    # --- Bandwidth Alliance edge proxies. These are Cloudflare Workers with no
    #     origin, and the egress waiver they exist for only applies to traffic
    #     that actually leaves through Cloudflare -- so they must not resolve to
    #     anything on the LAN. The *.munchbox.cc wildcard in dnsmasq would
    #     otherwise answer them with traefik, and a `server=` override cannot
    #     undo that: address= answers locally, so the query is never forwarded.
    #     An explicit record wins, which is why every catalogued service already
    #     reaches the VIP rather than the wildcard's address.
    #
    #     The address is a Cloudflare edge IP for the zone. Pinning one is safe
    #     because the edge routes by Host, so any Cloudflare address serves this
    #     zone even if the zone's own anycast pair changes. ---
    "b2-proxy"  = { domain = "b2-proxy.munchbox.cc", ip = "104.21.21.42" }
    "ibm-proxy" = { domain = "ibm-proxy.munchbox.cc", ip = "104.21.21.42" }
    "oci-proxy" = { domain = "oci-proxy.munchbox.cc", ip = "104.21.21.42" }
  }

  # --- munchbox.cc services from the shared catalog (root.locals.web_services)
  #     -> internal A-record at the traefik VIP. alexfreidah.com entries are
  #     public-only and skipped here. ---
  traefik_records = {
    for slug, svc in local.root.locals.web_services :
    slug => {
      domain = "${slug}.munchbox.cc"
      ip     = local.traefik_vip
    }
    if try(svc.zone, "munchbox") == "munchbox"
  }
}

inputs = {
  # --- pihole provider auth (was in root.hcl's generate "providers") ---
  pihole_primary_url        = local.root.locals.pihole_primary_url
  pihole_secondary_url      = local.root.locals.pihole_secondary_url
  pihole_password_primary   = get_env("TF_VAR_pihole_password_primary", "")
  pihole_password_secondary = get_env("TF_VAR_pihole_password_secondary", "")

  dns_records   = merge(local.traefik_records, local.pihole_special_dns_records)
  cname_records = {}
}
