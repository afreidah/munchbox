# -----------------------------------------------------------------------------
# consul-kv module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the for_each fan-out (one consul_keys per entry), datacenter
# propagation, and that an empty map produces no resources.
# -----------------------------------------------------------------------------

mock_provider "consul" {}

variables {
  keys = {
    "github/token-renewer/repos" = "afreidah/munchbox\nafreidah/g3"
    "some/other/key"             = "value"
  }
}

# -------------------------------------------------------------------------
# one consul_keys resource per map entry, datacenter propagates
# -------------------------------------------------------------------------

run "fan_out_per_entry" {
  command = plan

  # --- two entries -> two resources ---
  assert {
    condition     = length(consul_keys.this) == 2
    error_message = "two keys -> two consul_keys resources"
  }

  # --- datacenter default flows to the resource ---
  assert {
    condition     = consul_keys.this["some/other/key"].datacenter == "munchbox"
    error_message = "datacenter should default to munchbox"
  }

  # --- paths output lists every managed key (sorted) ---
  assert {
    condition     = toset(output.paths) == toset(["github/token-renewer/repos", "some/other/key"])
    error_message = "paths output should expose every managed key"
  }
}

# -------------------------------------------------------------------------
# empty map creates nothing
# -------------------------------------------------------------------------

run "empty_keys" {
  command = plan

  variables {
    keys = {}
  }

  # --- no entries -> no resources ---
  assert {
    condition     = length(consul_keys.this) == 0
    error_message = "empty keys map -> no consul_keys resources"
  }
}
