# -----------------------------------------------------------------------------
# NETWORKING MODULE (OCI) - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 32
    error_message = "Name must be between 1 and 32 characters."
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

variable "vcn_cidr" {
  description = "CIDR block for VCN"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "VCN CIDR must be valid CIDR notation."
  }
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "Subnet CIDR must be valid CIDR notation."
  }
}

variable "dns_label" {
  description = "DNS label for the VCN (alphanumeric, max 15 chars)"
  type        = string
  default     = "munchbox"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,14}$", var.dns_label))
    error_message = "DNS label must start with a letter, contain only lowercase alphanumeric characters, and be max 15 chars."
  }
}

variable "subnet_dns_label" {
  description = "DNS label for the subnet"
  type        = string
  default     = "main"
}

variable "security_list_ids" {
  description = "List of security list OCIDs to attach to the subnet"
  type        = list(string)
  default     = []
}
