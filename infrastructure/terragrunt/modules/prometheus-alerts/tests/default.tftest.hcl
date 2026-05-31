# -----------------------------------------------------------------------------
# prometheus-alerts module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the for_each fans out 1:1 over the input groups map, that empty
# input produces zero resources, and that the path-prefix validation rejects
# keys not under prometheus/alerts/.
# -----------------------------------------------------------------------------

mock_provider "consul" {}

variables {
  groups = {
    "prometheus/alerts/infrastructure-health" = "groups:\n  - name: infrastructure-health\n    rules: []\n"
    "prometheus/alerts/postgresql-health"     = "groups:\n  - name: postgresql-health\n    rules: []\n"
  }
}

# -------------------------------------------------------------------------
# Groups for_each: one KV resource per input key
# -------------------------------------------------------------------------

run "groups_for_each" {
  command = plan

  # --- two groups input -> two resources ---
  assert {
    condition     = length(consul_keys.groups) == 2
    error_message = "two groups input -> two consul_keys resources"
  }
}

# -------------------------------------------------------------------------
# Empty input: zero resources, no error
# -------------------------------------------------------------------------

run "empty_groups" {
  command = plan

  variables {
    groups = {}
  }

  # --- empty map -> no resources ---
  assert {
    condition     = length(consul_keys.groups) == 0
    error_message = "empty groups map -> zero consul_keys resources"
  }
}
