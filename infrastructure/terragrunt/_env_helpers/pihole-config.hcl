# -----------------------------------------------------------------------------
# PI-HOLE CONFIG ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the pihole-config module. URLs come from root.hcl;
# passwords from the same TF_VAR_* env vars pihole-dns uses.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//pihole-config"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  pihole_primary_url        = local.root.locals.pihole_primary_url
  pihole_secondary_url      = local.root.locals.pihole_secondary_url
  pihole_password_primary   = get_env("TF_VAR_pihole_password_primary", "")
  pihole_password_secondary = get_env("TF_VAR_pihole_password_secondary", "")

  # --- Pi 1 tuning: minimal SD wear + warm cache; recent visibility kept on ---
  max_db_days     = 7
  db_interval     = 600
  use_wal         = true
  parse_arp_cache = false
  privacy_level   = 0
  cache_size      = 20000
  query_logging   = true
  dnssec          = false
  upstream        = "127.0.0.1#5335"

  # --- explicit so terraform doesn't silently override live values ---
  etc_dnsmasq_d = true # MUST stay true so /etc/dnsmasq.d/*.conf is read
  expand_hosts  = false
  interface     = ""
  domain_name   = "lan"
}
