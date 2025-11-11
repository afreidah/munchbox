# -----------------------------------------------------------------------------
# NOMAD CLUSTER BASELINE
# -----------------------------------------------------------------------------
# Creates/controls:
#   - nomad_scheduler_config.global      : cluster-wide scheduler settings
#   - nomad_node_pool.this[<name>]       : node pools (Enterprise)
#   - nomad_namespace.this[<name>]       : namespaces, optional default pool
#
# Design:
#   - Import-friendly: one-to-one mapping with live cluster objects.
#   - Pool overrides are optional; unset => inherit global scheduler config.
#   - Namespaces allow optional default node pool (Enterprise).
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Global scheduler configuration
# -----------------------------------------------------------------------------
resource "nomad_scheduler_config" "global" {
  # Enables memory_max burst logic when capacity allows
  memory_oversubscription_enabled = var.scheduler.memory_oversubscription_enabled

  # Cluster scheduling strategy
  scheduler_algorithm = var.scheduler.scheduler_algorithm

  # Fine-grained preemption per queue
  preemption_config = {
    system   = try(var.scheduler.preemption.system,   true)
    service  = try(var.scheduler.preemption.service,  false)
    batch    = try(var.scheduler.preemption.batch,    false)
    sysbatch = try(var.scheduler.preemption.sysbatch, false)
  }
}

# -----------------------------------------------------------------------------
# Node pools (Enterprise)
# -----------------------------------------------------------------------------
# memory_oversubscription here uses strings ("enabled"|"disabled") so leaving
# it unset means "inherit global" rather than forcing a boolean false.
# -----------------------------------------------------------------------------
resource "nomad_node_pool" "this" {
  for_each    = var.node_pools
  name        = each.key
  description = coalesce(each.value.description, "")
  meta        = merge(each.value.meta, var.common_meta)

  dynamic "scheduler_config" {
    for_each = [1]
    content {
      # Inherit from global if null
      scheduler_algorithm     = try(each.value.scheduler_algorithm, null)
      memory_oversubscription = try(each.value.memory_oversubscription, null) # "enabled"|"disabled"
    }
  }
}

# -----------------------------------------------------------------------------
# Namespaces
# -----------------------------------------------------------------------------
resource "nomad_namespace" "this" {
  for_each    = { for n in var.namespaces : n.name => n }
  name        = each.value.name
  description = try(each.value.description, null)
  meta        = try(merge(each.value.meta, var.common_meta), null)

  # Only specify node_pool_config if provided (Enterprise)
  dynamic "node_pool_config" {
    for_each = try(each.value.node_pool_default, null) == null ? [] : [1]
    content {
      default = each.value.node_pool_default
    }
  }
}

