# -----------------------------------------------------------------------------
# BLOCK VOLUME MODULE (OCI) - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

variable "compartment_id" {
  description = "OCI compartment OCID"
  type        = string
}

variable "availability_domain" {
  description = "Availability domain for the volumes (must match instance AD)"
  type        = string
}

variable "instance_id" {
  description = "OCID of the instance to attach volumes to"
  type        = string
}

variable "volumes" {
  description = "List of block volumes to create and attach"
  type = list(object({
    name            = string
    size_gb         = number
    vpus_per_gb     = optional(number, 10)
    attachment_type = optional(string, "paravirtualized")
  }))

  validation {
    condition = alltrue([
      for v in var.volumes : v.size_gb >= 50 && v.size_gb <= 32768
    ])
    error_message = "Block volume size must be 50-32768 GB."
  }

  validation {
    condition = alltrue([
      for v in var.volumes : v.vpus_per_gb >= 0 && v.vpus_per_gb <= 120
    ])
    error_message = "vpus_per_gb must be 0-120."
  }

  validation {
    condition = alltrue([
      for v in var.volumes : contains(["paravirtualized", "iscsi"], v.attachment_type)
    ])
    error_message = "attachment_type must be paravirtualized or iscsi."
  }
}

variable "tags" {
  description = "Freeform tags applied to all volumes"
  type        = map(string)
  default     = {}
}
