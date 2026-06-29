# -----------------------------------------------------------------------------
# pihole-dns module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the dual-provider fan-out: each DNS / CNAME record renders once on
# the primary Pi-hole and once on the secondary, the for_each map keys
# mirror input keys, and empty record maps produce zero resources.
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
  pihole_password_primary   = "mock-primary-pass"
  pihole_password_secondary = "mock-secondary-pass"

  dns_records = {
    "alpha" = { domain = "alpha.test.cc", ip = "10.0.0.10" }
    "beta"  = { domain = "beta.test.cc", ip = "10.0.0.11" }
  }
  cname_records = {
    "alias-alpha" = { domain = "www.alpha.test.cc", target = "alpha.test.cc" }
  }
}

# -------------------------------------------------------------------------
# DNS A records render on BOTH primary and secondary providers
# -------------------------------------------------------------------------

run "dns_records_dual_render" {
  command = plan

  # --- primary instance gets one record per input ---
  assert {
    condition     = length(pihole_local_dns.primary) == 2
    error_message = "two dns_records -> two primary A records"
  }

  # --- secondary instance gets one record per input ---
  assert {
    condition     = length(pihole_local_dns.secondary) == 2
    error_message = "two dns_records -> two secondary A records"
  }

  # --- output: dns_records_primary keys mirror input map ---
  assert {
    condition     = toset(keys(output.dns_records_primary)) == toset(["alpha", "beta"])
    error_message = "dns_records_primary output must key alpha + beta"
  }

  # --- output: dns_records_primary value carries domain + ip ---
  assert {
    condition     = output.dns_records_primary["alpha"].domain == "alpha.test.cc" && output.dns_records_primary["alpha"].ip == "10.0.0.10"
    error_message = "dns_records_primary alpha must carry domain + ip"
  }

  # --- output: dns_records_secondary keys mirror input map ---
  assert {
    condition     = toset(keys(output.dns_records_secondary)) == toset(["alpha", "beta"])
    error_message = "dns_records_secondary output must key alpha + beta"
  }
}

# -------------------------------------------------------------------------
# CNAME records render on BOTH primary and secondary providers
# -------------------------------------------------------------------------

run "cname_records_dual_render" {
  command = plan

  # --- primary CNAME map mirrors input ---
  assert {
    condition     = length(pihole_cname_record.primary) == 1
    error_message = "one cname_record -> one primary CNAME"
  }

  # --- secondary CNAME map mirrors input ---
  assert {
    condition     = length(pihole_cname_record.secondary) == 1
    error_message = "one cname_record -> one secondary CNAME"
  }

  # --- output: cname_records_primary carries domain + target ---
  assert {
    condition     = output.cname_records_primary["alias-alpha"].domain == "www.alpha.test.cc" && output.cname_records_primary["alias-alpha"].target == "alpha.test.cc"
    error_message = "cname_records_primary alias-alpha must carry domain + target"
  }

  # --- output: cname_records_secondary carries domain + target ---
  assert {
    condition     = output.cname_records_secondary["alias-alpha"].domain == "www.alpha.test.cc" && output.cname_records_secondary["alias-alpha"].target == "alpha.test.cc"
    error_message = "cname_records_secondary alias-alpha must carry domain + target"
  }
}

# -------------------------------------------------------------------------
# for_each map keys mirror input map keys; values propagate
# -------------------------------------------------------------------------

run "for_each_keys_mirror_input" {
  command = plan

  # --- 'alpha' key exists in the primary map ---
  assert {
    condition     = contains(keys(pihole_local_dns.primary), "alpha")
    error_message = "primary DNS map must have key 'alpha'"
  }

  # --- hostname value propagates from input map (input still keyed .domain) ---
  assert {
    condition     = pihole_local_dns.primary["alpha"].hostname == "alpha.test.cc"
    error_message = "primary alpha record hostname must propagate from input .domain"
  }
}

# -------------------------------------------------------------------------
# Empty maps: zero resources on both Pi-holes, no errors
# -------------------------------------------------------------------------

run "empty_record_maps" {
  command = plan

  variables {
    dns_records   = {}
    cname_records = {}
  }

  # --- both Pi-holes have zero A records ---
  assert {
    condition     = length(pihole_local_dns.primary) == 0 && length(pihole_local_dns.secondary) == 0
    error_message = "empty dns_records -> zero A records on both pi-holes"
  }

  # --- both Pi-holes have zero CNAMEs ---
  assert {
    condition     = length(pihole_cname_record.primary) == 0 && length(pihole_cname_record.secondary) == 0
    error_message = "empty cname_records -> zero CNAMEs on both pi-holes"
  }
}
