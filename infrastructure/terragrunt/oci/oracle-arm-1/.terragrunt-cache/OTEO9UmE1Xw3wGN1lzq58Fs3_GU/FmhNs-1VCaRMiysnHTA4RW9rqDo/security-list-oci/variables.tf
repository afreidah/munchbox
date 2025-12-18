# -----------------------------------------------------------------------------
# SECURITY LIST MODULE (OCI) - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

variable "name" {
  description = "Display name for the security list"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "Name must be between 1 and 64 characters."
  }
}

variable "compartment_id" {
  description = "OCI compartment OCID"
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.", var.compartment_id))
    error_message = "Compartment ID must be a valid OCID."
  }
}

variable "vcn_id" {
  description = "OCID of the VCN"
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.vcn\\.", var.vcn_id))
    error_message = "VCN ID must be a valid VCN OCID."
  }
}

variable "ingress_rules" {
  description = "List of custom ingress rules"
  type = list(object({
    protocol    = string # "6" for TCP, "17" for UDP, "1" for ICMP, "all"
    source      = string
    description = string
    port_min    = optional(number)
    port_max    = optional(number)
  }))
  default = []
}

# -----------------------------------------------------------------------------
# PRESET VARIABLES
# -----------------------------------------------------------------------------

variable "allow_ssh" {
  description = "Allow SSH (port 22) from specified CIDR (set to null to disable)"
  type        = string
  default     = null
}

variable "allow_wireguard" {
  description = "Allow WireGuard (UDP 51820) from specified CIDR (set to null to disable)"
  type        = string
  default     = null
}

variable "allow_icmp" {
  description = "Allow ICMP (ping) from specified CIDR (set to null to disable)"
  type        = string
  default     = null
}

variable "trusted_cidr" {
  description = "CIDR block for trusted network - allows all TCP/UDP traffic"
  type        = string
  default     = null
}
