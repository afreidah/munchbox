# -----------------------------------------------------------------------------
# NOMAD-CONFIG MODULE - INPUT VARIABLES
#
# Project: Munchbox / Author: Alex Freidah
#
# Variable Categories:
#   - Scheduler: Algorithm, preemption, and memory oversubscription settings
#   - Node Pools: Logical pool definitions for workload placement
#   - Variables: Cluster-wide key/value stored in Raft
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# SCHEDULER CONFIGURATION
# -------------------------------------------------------------------------

variable "scheduler_algorithm" {
  description = "Scheduling algorithm for job placement: 'binpack' packs nodes tightly, 'spread' distributes evenly"
  type        = string
  default     = "spread"

  validation {
    condition     = contains(["binpack", "spread"], var.scheduler_algorithm)
    error_message = "scheduler_algorithm must be 'binpack' or 'spread'"
  }
}

variable "memory_oversubscription_enabled" {
  description = "Allow tasks to exceed their memory reservation (burst beyond reserved amount)"
  type        = bool
  default     = false
}

variable "preemption_config" {
  description = "Controls whether higher-priority jobs can evict lower-priority ones, per scheduler type"
  type = object({
    batch    = optional(bool, false)
    service  = optional(bool, false)
    sysbatch = optional(bool, false)
    system   = optional(bool, true)
  })
  default = {}
}

# -------------------------------------------------------------------------
# NODE POOLS
# -------------------------------------------------------------------------

variable "node_pools" {
  description = "Map of Nomad node pools to create (the built-in 'default' and 'all' pools cannot be managed)"
  type = map(object({
    description         = optional(string, "")
    scheduler_algorithm = optional(string, null)
  }))
  default = {}
}

# -------------------------------------------------------------------------
# VARIABLES
# -------------------------------------------------------------------------

variable "nomad_variables" {
  description = "Nomad variables to manage, keyed by path. Items are stored in Terraform state, so secrets belong in Vault rather than here"
  type = map(object({
    namespace = optional(string, "default")
    items     = map(string)
  }))
  default = {}
}
