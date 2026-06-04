# -----------------------------------------------------------------------------
# TEMPORAL-CONFIG MODULE - VARIABLES
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PROVIDER CONNECTION
# -----------------------------------------------------------------------------

variable "temporal_host" {
  description = "Temporal frontend host (gRPC)."
  type        = string
}

variable "temporal_port" {
  description = "Temporal frontend port (gRPC)."
  type        = string
  default     = "7233"
}

variable "temporal_insecure" {
  description = "Connect without TLS. True for the in-cluster plaintext frontend."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# SCHEDULES
# -----------------------------------------------------------------------------

variable "schedules" {
  description = "Map of Temporal schedules to manage; map key is the Terraform state key."
  type = map(object({
    schedule_id       = string
    namespace         = optional(string, "default")
    cron              = string
    time_zone         = optional(string, "America/Los_Angeles")
    jitter            = optional(string)
    workflow_type     = string
    task_queue        = string
    workflow_id       = string
    input             = optional(string)
    execution_timeout = optional(string)
    run_timeout       = optional(string)
    task_timeout      = optional(string)
    overlap_policy    = optional(string, "Skip")
    catchup_window    = optional(string)
    pause_on_failure  = optional(bool, false)
    paused            = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in var.schedules : contains(
        ["Skip", "BufferOne", "BufferAll", "CancelOther", "TerminateOther", "AllowAll"],
        s.overlap_policy
      )
    ])
    error_message = "overlap_policy must be one of Skip, BufferOne, BufferAll, CancelOther, TerminateOther, AllowAll."
  }
}
