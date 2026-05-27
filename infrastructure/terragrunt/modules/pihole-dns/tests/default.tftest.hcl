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
    condition     = length(pihole_dns_record.primary) == 2
    error_message = "two dns_records -> two primary A records"
  }

  # --- secondary instance gets one record per input ---
  assert {
    condition     = length(pihole_dns_record.secondary) == 2
    error_message = "two dns_records -> two secondary A records"
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
}

# -------------------------------------------------------------------------
# for_each map keys mirror input map keys; values propagate
# -------------------------------------------------------------------------

run "for_each_keys_mirror_input" {
  command = plan

  # --- 'alpha' key exists in the primary map ---
  assert {
    condition     = contains(keys(pihole_dns_record.primary), "alpha")
    error_message = "primary DNS map must have key 'alpha'"
  }

  # --- domain value propagates from input map ---
  assert {
    condition     = pihole_dns_record.primary["alpha"].domain == "alpha.test.cc"
    error_message = "primary alpha record domain must propagate"
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
    condition     = length(pihole_dns_record.primary) == 0 && length(pihole_dns_record.secondary) == 0
    error_message = "empty dns_records -> zero A records on both pi-holes"
  }

  # --- both Pi-holes have zero CNAMEs ---
  assert {
    condition     = length(pihole_cname_record.primary) == 0 && length(pihole_cname_record.secondary) == 0
    error_message = "empty cname_records -> zero CNAMEs on both pi-holes"
  }
}
