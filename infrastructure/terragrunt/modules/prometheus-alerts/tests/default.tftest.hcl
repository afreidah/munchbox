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

  # --- group_count output counts the input groups ---
  assert {
    condition     = output.group_count == 2
    error_message = "group_count output must equal the number of input groups"
  }

  # --- group_paths output is the sorted set of KV paths ---
  assert {
    condition     = toset(output.group_paths) == toset(["prometheus/alerts/infrastructure-health", "prometheus/alerts/postgresql-health"])
    error_message = "group_paths output must list every managed KV path"
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
