# -----------------------------------------------------------------------------
# NOMAD-CONFIG MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages cluster-level Nomad configuration stored in Raft. These settings
# cannot be defined in server config files — they must be applied via API or
# Terraform. Covers scheduler algorithm, preemption, memory oversubscription,
# and node pool definitions.
#
# Components:
#   - Scheduler Config: Algorithm (binpack/spread), preemption, oversubscription
#   - Node Pools: Logical groupings for workload placement constraints
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# SCHEDULER CONFIGURATION
# -------------------------------------------------------------------------

resource "nomad_scheduler_config" "cluster" {
  scheduler_algorithm             = var.scheduler_algorithm
  memory_oversubscription_enabled = var.memory_oversubscription_enabled

  preemption_config = {
    batch_scheduler_enabled    = var.preemption_config.batch
    service_scheduler_enabled  = var.preemption_config.service
    sysbatch_scheduler_enabled = var.preemption_config.sysbatch
    system_scheduler_enabled   = var.preemption_config.system
  }
}

# -------------------------------------------------------------------------
# NODE POOLS
# -------------------------------------------------------------------------

resource "nomad_node_pool" "pool" {
  for_each = var.node_pools

  name        = each.key
  description = each.value.description

  dynamic "scheduler_config" {
    for_each = each.value.scheduler_algorithm != null ? [each.value.scheduler_algorithm] : []
    content {
      scheduler_algorithm = scheduler_config.value
    }
  }
}
