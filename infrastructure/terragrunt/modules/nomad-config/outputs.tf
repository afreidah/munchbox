# -----------------------------------------------------------------------------
# NOMAD-CONFIG MODULE - OUTPUT VALUES
#
# Project: Munchbox / Author: Alex Freidah
#
# Output Categories:
#   - Scheduler: Current scheduler configuration
#   - Node Pools: Created pool names
#   - Variables: Managed variable paths
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# SCHEDULER CONFIGURATION
# -------------------------------------------------------------------------

output "scheduler_algorithm" {
  description = "Active scheduler algorithm"
  value       = nomad_scheduler_config.cluster.scheduler_algorithm
}

# -------------------------------------------------------------------------
# NODE POOLS
# -------------------------------------------------------------------------

output "node_pools" {
  description = "Map of created node pool names"
  value       = { for k, v in nomad_node_pool.pool : k => v.name }
}

# -------------------------------------------------------------------------
# VARIABLES
# -------------------------------------------------------------------------

# --- paths only; items are not echoed, so a secret set here by mistake does
#     not also land in a consumer's state ---
output "nomad_variable_paths" {
  description = "Paths of the managed Nomad variables"
  value       = sort([for v in nomad_variable.this : v.path])
}
