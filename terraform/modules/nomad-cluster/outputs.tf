# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

# Scheduler configuration summary (cluster-wide)
output "scheduler_config" {
  description = "Resolved scheduler configuration (cluster-wide)."
  value = {
    memory_oversubscription_enabled = nomad_scheduler_config.global.memory_oversubscription_enabled
    scheduler_algorithm             = nomad_scheduler_config.global.scheduler_algorithm
    preemption_config               = nomad_scheduler_config.global.preemption_config
  }
}

# Node pool names and selected overrides
output "node_pools" {
  description = "Node pool definitions (names and overrides) managed by this module."
  value = {
    names = keys(nomad_node_pool.this)
    overrides = {
      for k, v in nomad_node_pool.this :
      k => {
        scheduler_algorithm     = try(v.scheduler_config[0].scheduler_algorithm, null)
        memory_oversubscription = try(v.scheduler_config[0].memory_oversubscription, null)
        meta                    = v.meta
      }
    }
  }
}

# Namespace list and default pools
output "namespaces" {
  description = "Namespaces and their default node pools (if any)."
  value = {
    for k, v in nomad_namespace.this :
    k => {
      description       = v.description
      meta              = v.meta
      node_pool_default = try(v.node_pool_config[0].default, null)
    }
  }
}
