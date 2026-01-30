# -----------------------------------------------------------------------------
# COMPUTE MODULE (OCI) - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "name" {
  description = "Display name for the instance"
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

variable "availability_domain" {
  description = "Availability domain name"
  type        = string
}

variable "subnet_id" {
  description = "OCID of the subnet"
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.subnet\\.", var.subnet_id))
    error_message = "Subnet ID must be a valid subnet OCID."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

# -----------------------------------------------------------------------------
# SHAPE CONFIGURATION
# -----------------------------------------------------------------------------

variable "shape" {
  description = "Instance shape (e.g., VM.Standard.E2.1.Micro, VM.Standard.A1.Flex)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "Number of OCPUs (only for flexible shapes like A1.Flex)"
  type        = number
  default     = null
}

variable "memory_gb" {
  description = "Memory in GB (only for flexible shapes, defaults to 6GB per OCPU)"
  type        = number
  default     = null
}

# -----------------------------------------------------------------------------
# STORAGE
# -----------------------------------------------------------------------------

variable "boot_volume_gb" {
  description = "Boot volume size in GB"
  type        = number
  default     = 50

  validation {
    condition     = var.boot_volume_gb >= 50 && var.boot_volume_gb <= 32768
    error_message = "Boot volume must be between 50 and 32768 GB."
  }
}

# -----------------------------------------------------------------------------
# IMAGE
# -----------------------------------------------------------------------------

variable "image_id" {
  description = "Specific image OCID (overrides automatic lookup)"
  type        = string
  default     = null
}

variable "ubuntu_version" {
  description = "Ubuntu version for automatic image lookup"
  type        = string
  default     = "24.04"
}

# -----------------------------------------------------------------------------
# NETWORKING
# -----------------------------------------------------------------------------

variable "assign_public_ip" {
  description = "Assign a public IP address"
  type        = bool
  default     = true
}

variable "hostname_label" {
  description = "Hostname label for DNS (defaults to sanitized name)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# BOOTSTRAPPING
# -----------------------------------------------------------------------------

variable "user_data" {
  description = "Cloud-init user data script"
  type        = string
  default     = null
}
