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
    schedule_id = string
    namespace   = optional(string, "default")
    # Calendar fields (not cron): the provider stores schedules as a structured
    # calendar and reads them back that way, so a cron string never converges.
    # Defaults are the server's canonical wildcards for an unset field.
    year              = optional(string, "*")
    minute            = optional(string, "0")
    hour              = string
    day_of_month      = optional(string, "1-31")
    month             = optional(string, "1-12")
    day_of_week       = optional(string, "0-6")
    second            = optional(string, "0")
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
