# -----------------------------------------------------------------------------
# NOMAD CLUSTER MODULE TESTS
# -----------------------------------------------------------------------------
# Plan-only tests that validate module logic and expected resource shapes.
# Run with: terraform test
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Test: Basic scheduler + two node pools + two namespaces
# -----------------------------------------------------------------------------
run "baseline_cluster" {
  command = plan

  variables {
    scheduler = {
      memory_oversubscription_enabled = true
      scheduler_algorithm             = "binpack"
      preemption = {
        system   = true
        service  = false
        batch    = false
        sysbatch = false
      }
    }

    node_pools = {
      all = {
        description             = "Built-in pool for all clients"
        # inherit global scheduler settings by leaving overrides unset
      }
      bursty = {
        description             = "High-burst services"
        scheduler_algorithm     = "spread"
        memory_oversubscription = "enabled"
      }
    }

    namespaces = [
      { name = "default",  description = "Default namespace",  node_pool_default = "all" },
      { name = "registry", description = "Registry workloads", node_pool_default = "bursty" }
    ]

    common_meta = {
      ManagedBy = "Terraform"
    }
  }

  # --- Scheduler assertions ---
  assert {
    condition     = nomad_scheduler_config.global.memory_oversubscription_enabled == true
    error_message = "Scheduler should enable memory oversubscription cluster-wide."
  }

  assert {
    condition     = nomad_scheduler_config.global.scheduler_algorithm == "binpack"
    error_message = "Scheduler algorithm should be 'binpack'."
  }

  # --- Node pool assertions ---
  # Pool 'bursty' explicitly enables memory oversubscription and sets 'spread'
  assert {
    condition     = nomad_node_pool.this["bursty"].scheduler_config[0].memory_oversubscription == "enabled"
    error_message = "Pool 'bursty' should enable memory oversubscription."
  }

  assert {
    condition     = nomad_node_pool.this["bursty"].scheduler_config[0].scheduler_algorithm == "spread"
    error_message = "Pool 'bursty' should set scheduler_algorithm to 'spread'."
  }

  # Pool 'all' inherits global settings; override attributes should be null
  assert {
    condition     = try(nomad_node_pool.this["all"].scheduler_config[0].memory_oversubscription, null) == null
    error_message = "Pool 'all' should inherit memory oversubscription (no explicit override)."
  }

  assert {
    condition     = try(nomad_node_pool.this["all"].scheduler_config[0].scheduler_algorithm, null) == null
    error_message = "Pool 'all' should inherit scheduler_algorithm (no explicit override)."
  }

  # --- Namespace assertions ---
  assert {
    condition     = nomad_namespace.this["default"].name == "default"
    error_message = "Namespace 'default' should be created."
  }

  assert {
    condition     = nomad_namespace.this["default"].node_pool_config[0].default == "all"
    error_message = "Namespace 'default' should default to node pool 'all'."
  }

  assert {
    condition     = nomad_namespace.this["registry"].node_pool_config[0].default == "bursty"
    error_message = "Namespace 'registry' should default to node pool 'bursty'."
  }
}

