# -----------------------------------------------------------------------------
# nomad-config module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the scheduler config flows through, preemption flags map 1:1 from
# the input shape to the nomad attribute names, node_pools for_each fans out
# correctly, the dynamic scheduler_config block only renders when a per-pool
# algorithm is set, and nomad_variables fan out one resource per path.
# -----------------------------------------------------------------------------

mock_provider "nomad" {}

variables {
  scheduler_algorithm             = "spread"
  memory_oversubscription_enabled = false
  preemption_config = {
    batch    = false
    service  = false
    sysbatch = false
    system   = true
  }
  node_pools = {
    "oracle" = { description = "Oracle Cloud nodes", scheduler_algorithm = null }
    "edge"   = { description = "edge nodes", scheduler_algorithm = "binpack" }
  }
  nomad_variables = {
    "cluster/identity" = { items = { name = "example" } }
    "tooling/settings" = { namespace = "tooling", items = { enabled = "true", mode = "fast" } }
  }
}

# -------------------------------------------------------------------------
# Scheduler attributes flow through from vars
# -------------------------------------------------------------------------

run "scheduler_config_propagates" {
  command = plan

  # --- scheduler_algorithm matches input var ---
  assert {
    condition     = nomad_scheduler_config.cluster.scheduler_algorithm == var.scheduler_algorithm
    error_message = "scheduler_algorithm must match var"
  }

  # --- memory_oversubscription_enabled matches input var ---
  assert {
    condition     = nomad_scheduler_config.cluster.memory_oversubscription_enabled == false
    error_message = "memory_oversubscription_enabled must match var"
  }

  # --- OUTPUT: scheduler_algorithm echoes the input var ---
  assert {
    condition     = output.scheduler_algorithm == var.scheduler_algorithm
    error_message = "output.scheduler_algorithm must echo var.scheduler_algorithm"
  }
}

# -------------------------------------------------------------------------
# preemption_config map keys remap from short names to nomad attr names
# -------------------------------------------------------------------------

run "preemption_field_mapping" {
  command = plan

  # --- short 'batch' maps to nomad's batch_scheduler_enabled ---
  assert {
    condition     = nomad_scheduler_config.cluster.preemption_config.batch_scheduler_enabled == var.preemption_config.batch
    error_message = "preemption_config.batch must map to batch_scheduler_enabled"
  }

  # --- short 'system' maps to nomad's system_scheduler_enabled ---
  assert {
    condition     = nomad_scheduler_config.cluster.preemption_config.system_scheduler_enabled == true
    error_message = "preemption_config.system=true must map to system_scheduler_enabled=true"
  }
}

# -------------------------------------------------------------------------
# node_pools for_each: one resource per map entry
# -------------------------------------------------------------------------

run "node_pools_for_each" {
  command = plan

  # --- two pools input -> two resources ---
  assert {
    condition     = length(nomad_node_pool.pool) == 2
    error_message = "two node_pools input -> two resources"
  }

  # --- oracle key exists in the for_each map ---
  assert {
    condition     = contains(keys(nomad_node_pool.pool), "oracle")
    error_message = "oracle pool must exist"
  }

  # --- description propagates from var.node_pools[key].description ---
  assert {
    condition     = nomad_node_pool.pool["oracle"].description == "Oracle Cloud nodes"
    error_message = "node pool description must come from var.node_pools[key]"
  }

  # --- OUTPUT: node_pools map has one entry per input pool ---
  assert {
    condition     = toset(keys(output.node_pools)) == toset(["oracle", "edge"])
    error_message = "output.node_pools must contain a key per input node pool"
  }
}

# -------------------------------------------------------------------------
# Dynamic scheduler_config block only renders when scheduler_algorithm set
# -------------------------------------------------------------------------

run "dynamic_scheduler_config_conditional" {
  command = plan

  # --- pool with null algorithm has no scheduler_config block ---
  assert {
    condition     = length(nomad_node_pool.pool["oracle"].scheduler_config) == 0
    error_message = "oracle (algorithm=null) should NOT render scheduler_config block"
  }

  # --- pool with explicit algorithm has one scheduler_config block ---
  assert {
    condition     = length(nomad_node_pool.pool["edge"].scheduler_config) == 1
    error_message = "edge (algorithm=\"binpack\") should render scheduler_config block"
  }
}

# -------------------------------------------------------------------------
# Empty node_pools edge case: zero resources
# -------------------------------------------------------------------------

run "empty_node_pools" {
  command = plan

  variables {
    node_pools = {}
  }

  # --- empty map produces zero resources ---
  assert {
    condition     = length(nomad_node_pool.pool) == 0
    error_message = "empty node_pools should produce zero resources"
  }
}

# -------------------------------------------------------------------------
# nomad_variables for_each: the map key is the variable path
# -------------------------------------------------------------------------

run "nomad_variables_for_each" {
  command = plan

  # --- two paths input -> two resources ---
  assert {
    condition     = length(nomad_variable.this) == 2
    error_message = "two nomad_variables input -> two resources"
  }

  # --- the map key is the path, not a separate attribute to keep in step ---
  assert {
    condition     = nomad_variable.this["cluster/identity"].path == "cluster/identity"
    error_message = "variable path must come from the map key"
  }

  # --- items propagate verbatim ---
  assert {
    condition     = nomad_variable.this["cluster/identity"].items["name"] == "example"
    error_message = "items must come from var.nomad_variables[key].items"
  }

  # --- a path carrying several items keeps all of them ---
  assert {
    condition     = length(nomad_variable.this["tooling/settings"].items) == 2
    error_message = "all items for a path must be set"
  }

  # --- namespace defaults to default when the caller omits it ---
  assert {
    condition     = nomad_variable.this["cluster/identity"].namespace == "default"
    error_message = "namespace must default to 'default'"
  }

  # --- an explicit namespace overrides the default ---
  assert {
    condition     = nomad_variable.this["tooling/settings"].namespace == "tooling"
    error_message = "explicit namespace must be honoured"
  }

  # --- OUTPUT: paths are reported, items are not ---
  assert {
    condition     = output.nomad_variable_paths == tolist(["cluster/identity", "tooling/settings"])
    error_message = "output.nomad_variable_paths must list every managed path, sorted"
  }
}

# -------------------------------------------------------------------------
# Empty nomad_variables edge case: zero resources
# -------------------------------------------------------------------------

run "empty_nomad_variables" {
  command = plan

  variables {
    nomad_variables = {}
  }

  # --- a module that manages no variables creates none ---
  assert {
    condition     = length(nomad_variable.this) == 0
    error_message = "empty nomad_variables should produce zero resources"
  }

  # --- and reports an empty path list rather than null ---
  assert {
    condition     = length(output.nomad_variable_paths) == 0
    error_message = "output.nomad_variable_paths must be empty, not null"
  }
}
