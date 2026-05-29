# -----------------------------------------------------------------------------
# PI-HOLE DNS ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the pihole-dns module. root.hcl holds the static data
# (traefik_fronted_hosts list + traefik_vip + pihole_special_dns_records map);
# this helper expands the list into the per-host A-record map the module
# expects and merges in the special records.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/pihole-dns"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  # --- Expand traefik_fronted_hosts into the dns_records shape the module
  #     wants: { <slug> = { domain = "<slug>.munchbox.cc", ip = traefik_vip } } ---
  traefik_records = {
    for host in local.root.locals.traefik_fronted_hosts :
    host => {
      domain = "${host}.munchbox.cc"
      ip     = local.root.locals.traefik_vip
    }
  }
}

inputs = {
  # --- pihole provider auth (was in root.hcl's generate "providers") ---
  pihole_primary_url        = local.root.locals.pihole_primary_url
  pihole_secondary_url      = local.root.locals.pihole_secondary_url
  pihole_password_primary   = get_env("TF_VAR_pihole_password_primary", "")
  pihole_password_secondary = get_env("TF_VAR_pihole_password_secondary", "")

  dns_records   = merge(local.traefik_records, local.root.locals.pihole_special_dns_records)
  cname_records = {}
}
