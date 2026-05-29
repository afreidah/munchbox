# -----------------------------------------------------------------------------
# PI-HOLE CONFIG MODULE
# -----------------------------------------------------------------------------
#
# Manages pihole.toml-shaped settings via the dklesev/pihole v6 REST API.
# Three singletons per node (database / misc / upstream) replicated across
# both Pi-hole instances via primary + secondary provider aliases.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# --- database: retention, flush interval, WAL, ARP parse ---

resource "pihole_config_database" "primary" {
  provider        = pihole.primary
  max_db_days     = var.max_db_days
  db_interval     = var.db_interval
  use_wal         = var.use_wal
  parse_arp_cache = var.parse_arp_cache
}

resource "pihole_config_database" "secondary" {
  provider        = pihole.secondary
  max_db_days     = var.max_db_days
  db_interval     = var.db_interval
  use_wal         = var.use_wal
  parse_arp_cache = var.parse_arp_cache
}

# --- misc: privacy level ---

resource "pihole_config_misc" "primary" {
  provider      = pihole.primary
  privacy_level = var.privacy_level
  etc_dnsmasq_d = var.etc_dnsmasq_d
}

resource "pihole_config_misc" "secondary" {
  provider      = pihole.secondary
  privacy_level = var.privacy_level
  etc_dnsmasq_d = var.etc_dnsmasq_d
}

# --- dns: cache size, query log, dnssec ---

resource "pihole_config_dns" "primary" {
  provider      = pihole.primary
  cache_size    = var.cache_size
  query_logging = var.query_logging
  dnssec        = var.dnssec
  expand_hosts  = var.expand_hosts
  interface     = var.interface
  domain_name   = var.domain_name
}

resource "pihole_config_dns" "secondary" {
  provider      = pihole.secondary
  cache_size    = var.cache_size
  query_logging = var.query_logging
  dnssec        = var.dnssec
  expand_hosts  = var.expand_hosts
  interface     = var.interface
  domain_name   = var.domain_name
}

# --- upstream DNS (= local unbound on 127.0.0.1#5335) ---

resource "pihole_dns_upstream" "primary" {
  provider = pihole.primary
  upstream = var.upstream
}

resource "pihole_dns_upstream" "secondary" {
  provider = pihole.secondary
  upstream = var.upstream
}
