# -----------------------------------------------------------------------------
# pihole-config module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the dual-provider fan-out: each settings resource renders once on
# primary and once on secondary, and inputs propagate through.
# -----------------------------------------------------------------------------

mock_provider "pihole" {
  alias = "primary"
}

mock_provider "pihole" {
  alias = "secondary"
}

variables {
  pihole_primary_url        = "http://mock-primary.test"
  pihole_secondary_url      = "http://mock-secondary.test"
  pihole_password_primary   = "mock-primary"
  pihole_password_secondary = "mock-secondary"

  max_db_days     = 7
  db_interval     = 600
  use_wal         = true
  parse_arp_cache = false
  privacy_level   = 0
  cache_size      = 20000
  query_logging   = true
  dnssec          = false
  upstream        = "127.0.0.1#5335"
  etc_dnsmasq_d   = true
  expand_hosts    = false
  interface       = ""
  domain_name     = "lan"
}

# -------------------------------------------------------------------------
# database settings render on both providers
# -------------------------------------------------------------------------

run "database_dual_render" {
  command = plan

  # --- primary max_db_days propagates ---
  assert {
    condition     = pihole_config_database.primary.max_db_days == 7
    error_message = "primary max_db_days must propagate"
  }

  # --- secondary db_interval propagates ---
  assert {
    condition     = pihole_config_database.secondary.db_interval == 600
    error_message = "secondary db_interval must propagate"
  }

  # --- use_wal + parse_arp_cache propagate ---
  assert {
    condition     = pihole_config_database.primary.use_wal && !pihole_config_database.primary.parse_arp_cache
    error_message = "primary db booleans must propagate"
  }
}

# -------------------------------------------------------------------------
# dns settings render on both providers
# -------------------------------------------------------------------------

run "dns_dual_render" {
  command = plan

  # --- cache_size propagates ---
  assert {
    condition     = pihole_config_dns.primary.cache_size == 20000
    error_message = "primary cache_size must propagate"
  }

  # --- query_logging + dnssec propagate ---
  assert {
    condition     = pihole_config_dns.secondary.query_logging && !pihole_config_dns.secondary.dnssec
    error_message = "secondary dns booleans must propagate"
  }
}

# -------------------------------------------------------------------------
# misc.privacy_level renders on both
# -------------------------------------------------------------------------

run "misc_dual_render" {
  command = plan

  # --- primary privacy_level ---
  assert {
    condition     = pihole_config_misc.primary.privacy_level == 0
    error_message = "primary privacy_level must propagate"
  }

  # --- secondary privacy_level ---
  assert {
    condition     = pihole_config_misc.secondary.privacy_level == 0
    error_message = "secondary privacy_level must propagate"
  }
}

# -------------------------------------------------------------------------
# upstream renders on both
# -------------------------------------------------------------------------

run "upstream_dual_render" {
  command = plan

  # --- primary upstream ---
  assert {
    condition     = pihole_dns_upstream.primary.upstream == "127.0.0.1#5335"
    error_message = "primary upstream must propagate"
  }

  # --- secondary upstream ---
  assert {
    condition     = pihole_dns_upstream.secondary.upstream == "127.0.0.1#5335"
    error_message = "secondary upstream must propagate"
  }
}
