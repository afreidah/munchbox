# -----------------------------------------------------------------------------
# PI-HOLE DNS ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the pihole-dns module. The static data lives here
# (traefik_fronted_hosts list + traefik_vip + pihole_special_dns_records map;
# pihole_primary/secondary_url come from root.hcl); this helper expands the
# list into the per-host A-record map the module expects and merges in the
# special records.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/pihole-dns"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  traefik_vip = "192.168.68.50"

  # --- hosts that route to the traefik VIP ---
  traefik_fronted_hosts = [
    "alertmanager", "analytics", "apt", "auth", "consul", "dashboard",
    "deluge", "ersatz", "git", "grafana", "jellyfin", "kavita", "lidarr",
    "nomad", "photos", "prometheus", "prowlarr", "radarr",
    "readarr", "registry", "registry-ui", "sonarr", "temporal", "themes",
    "traefik", "traefik-logs", "trivy-dashboard", "vault", "vault-ui",
    "vaultwarden", "pihole", "s3", "forgejo",
  ]

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
    "pihole-green"    = { domain = "pihole-green.munchbox.cc", ip = "192.168.68.62" }
    "pihole-logan"    = { domain = "pihole-logan.munchbox.cc", ip = "192.168.68.64" }
  }

  # --- Expand traefik_fronted_hosts into the dns_records shape the module
  #     wants: { <slug> = { domain = "<slug>.munchbox.cc", ip = traefik_vip } } ---
  traefik_records = {
    for host in local.traefik_fronted_hosts :
    host => {
      domain = "${host}.munchbox.cc"
      ip     = local.traefik_vip
    }
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
