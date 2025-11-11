# -----------------------------------------------------------------------------
# VARIABLES
# -----------------------------------------------------------------------------
# Inputs are structured to be import-friendly and map to Nomad concepts:
#   - Scheduler configuration (cluster-wide)
#   - Node pools (Enterprise): optional per-pool scheduler overrides
#   - Namespaces: ensure basic namespaces exist, optionally default a pool
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Scheduler configuration (cluster-wide)
# -----------------------------------------------------------------------------
variable "scheduler" {
  description = <<EOT
Global scheduler settings:
  - memory_oversubscription_enabled (bool): enables honoring memory_max on tasks
  - scheduler_algorithm (string): "binpack" | "spread" (default "binpack")
  - preemption (object): booleans per scheduler queue
EOT
  type = object({
    memory_oversubscription_enabled = bool
    scheduler_algorithm             = optional(string, "binpack")
    preemption = optional(object({
      system   = optional(bool, true)
      service  = optional(bool, false)
      batch    = optional(bool, false)
      sysbatch = optional(bool, false)
    }), {})
  })
}

# -----------------------------------------------------------------------------
# Node pools (Nomad Enterprise)
# -----------------------------------------------------------------------------
variable "node_pools" {
  description = <<EOT
Map of node pools by name. Optional per-pool scheduler overrides:
  - scheduler_algorithm: "binpack" | "spread" (unset -> inherit global)
  - memory_oversubscription: "enabled" | "disabled" (unset -> inherit global)
EOT
  type = map(object({
    description             = optional(string)
    meta                    = optional(map(string), {})
    scheduler_algorithm     = optional(string)
    memory_oversubscription = optional(string)
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Namespaces
# -----------------------------------------------------------------------------
variable "namespaces" {
  description = <<EOT
List of namespaces to create. For Enterprise, you can set a default node pool:
  - node_pool_default: pool name to set as default for the namespace
EOT
  type = list(object({
    name              = string
    description       = optional(string)
    meta              = optional(map(string), {})
    node_pool_default = optional(string)
  }))
  default = []
}

# -----------------------------------------------------------------------------
# Common tags / labels (passed through to resources that support them)
# -----------------------------------------------------------------------------
variable "common_meta" {
  description = "Key/value metadata applied where supported (Nomad meta fields)."
  type        = map(string)
  default     = {}
}

