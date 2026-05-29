# -----------------------------------------------------------------------------
# PIHOLE-CONFIG MODULE - OUTPUTS
# -----------------------------------------------------------------------------

output "database_ids" {
  description = "pihole_config_database resource ids per node."
  value = {
    primary   = pihole_config_database.primary.id
    secondary = pihole_config_database.secondary.id
  }
}

output "misc_ids" {
  description = "pihole_config_misc resource ids per node."
  value = {
    primary   = pihole_config_misc.primary.id
    secondary = pihole_config_misc.secondary.id
  }
}

output "dns_ids" {
  description = "pihole_config_dns resource ids per node."
  value = {
    primary   = pihole_config_dns.primary.id
    secondary = pihole_config_dns.secondary.id
  }
}

output "upstream_ids" {
  description = "pihole_dns_upstream resource ids per node."
  value = {
    primary   = pihole_dns_upstream.primary.id
    secondary = pihole_dns_upstream.secondary.id
  }
}
