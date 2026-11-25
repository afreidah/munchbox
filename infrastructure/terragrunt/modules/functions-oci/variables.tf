# -----------------------------------------------------------------------------
# FUNCTIONS-OCI Module Variables
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TENANCY
# -----------------------------------------------------------------------------

variable "tenancy_ocid" {
  description = "Tenancy OCID; the compartment, user, group and policy are created in the tenancy root."
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.tenancy\\.", var.tenancy_ocid))
    error_message = "tenancy_ocid must be a tenancy OCID."
  }
}

variable "region" {
  description = "OCI region the functions run in; carried in vault_data for the consumer's API calls."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets the application's functions run in; the subnet needs a route to OCI services."
  type        = list(string)
}

# -----------------------------------------------------------------------------
# APPLICATION
# -----------------------------------------------------------------------------

variable "name" {
  description = "Consumer the application serves; names its compartment, application, user, group and policy."
  type        = string
}

variable "user_email" {
  description = "Email of the invoking user; Identity Domains tenancies require one, unique per user."
  type        = string
}

variable "shape" {
  description = "Processor shape the application's functions run on."
  type        = string
  default     = "GENERIC_X86"

  validation {
    condition     = contains(["GENERIC_X86", "GENERIC_ARM", "GENERIC_X86_ARM"], var.shape)
    error_message = "shape must be GENERIC_X86, GENERIC_ARM or GENERIC_X86_ARM."
  }
}

variable "tags" {
  description = "Freeform tags on every resource the module creates."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# FUNCTIONS
# -----------------------------------------------------------------------------

variable "functions" {
  description = <<-EOT
    Code-only functions in the application, keyed by function name. files maps
    each path inside the archive to that file's contents, so the archive takes
    whatever layout the runtime requires: function/func.py for Python. handler
    is required by the Python, Java and Node.js runtimes and omitted for Go.
  EOT

  type = map(object({
    files              = map(string)
    runtime            = string
    handler            = optional(string)
    memory_in_mbs      = optional(number, 128)
    timeout_in_seconds = optional(number, 30)
  }))

  default = {}

  validation {
    condition     = alltrue([for f in values(var.functions) : length(f.files) > 0])
    error_message = "Every function needs at least one file in its archive."
  }

  validation {
    condition     = alltrue([for f in values(var.functions) : contains([128, 256, 512, 1024, 2048, 3072], f.memory_in_mbs)])
    error_message = "memory_in_mbs must be one of 128, 256, 512, 1024, 2048 or 3072."
  }

  validation {
    condition     = alltrue([for f in values(var.functions) : f.timeout_in_seconds >= 1 && f.timeout_in_seconds <= 300])
    error_message = "timeout_in_seconds must be between 1 and 300, the longest synchronous invoke."
  }
}
