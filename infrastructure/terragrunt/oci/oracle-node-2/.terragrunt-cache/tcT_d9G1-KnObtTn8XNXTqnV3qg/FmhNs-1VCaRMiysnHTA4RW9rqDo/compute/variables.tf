# -----------------------------------------------------------------------------
# UNIFIED COMPUTE MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PROVIDER SELECTION
# -----------------------------------------------------------------------------

variable "provider_type" {
  description = "Cloud/infrastructure provider: aws, oci, or proxmox"
  type        = string

  validation {
    condition     = contains(["aws", "oci", "proxmox"], var.provider_type)
    error_message = "Provider type must be 'aws', 'oci', or 'proxmox'."
  }
}

# -----------------------------------------------------------------------------
# UNIVERSAL INTERFACE
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name of the instance/VM"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "Name must be between 1 and 64 characters."
  }
}

variable "cpu" {
  description = "Number of CPU cores/vCPUs/OCPUs"
  type        = number
  default     = 2

  validation {
    condition     = var.cpu >= 1 && var.cpu <= 128
    error_message = "CPU must be between 1 and 128."
  }
}

variable "memory_gb" {
  description = "Memory in GB"
  type        = number
  default     = 4

  validation {
    condition     = var.memory_gb >= 1 && var.memory_gb <= 512
    error_message = "Memory must be between 1 and 512 GB."
  }
}

variable "disk_gb" {
  description = "Root/boot disk size in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.disk_gb >= 8 && var.disk_gb <= 32768
    error_message = "Disk size must be between 8 and 32768 GB."
  }
}

variable "ssh_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "user_data" {
  description = "Cloud-init user data script for bootstrapping"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources (where supported)"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# AWS-SPECIFIC CONFIGURATION
# -----------------------------------------------------------------------------

variable "aws_config" {
  description = "AWS-specific configuration (required when provider_type = 'aws')"
  type = object({
    subnet_id             = string
    security_group_ids    = list(string)
    instance_type         = optional(string)       # Override auto-selected type
    architecture          = optional(string)       # "arm64" or "x86_64"
    spot_type             = optional(string)       # "persistent" or "one-time"
    interruption_behavior = optional(string)       # "stop" or "terminate"
    assign_elastic_ip     = optional(bool)
  })
  default = null

  validation {
    condition     = var.aws_config == null || (var.aws_config.subnet_id != null && var.aws_config.security_group_ids != null)
    error_message = "AWS config requires subnet_id and security_group_ids."
  }
}

# -----------------------------------------------------------------------------
# OCI-SPECIFIC CONFIGURATION
# -----------------------------------------------------------------------------

variable "oci_config" {
  description = "OCI-specific configuration (required when provider_type = 'oci')"
  type = object({
    compartment_id      = string
    availability_domain = string
    subnet_id           = string
    shape               = optional(string) # Override auto-selected shape
  })
  default = null

  validation {
    condition     = var.oci_config == null || (var.oci_config.compartment_id != null && var.oci_config.availability_domain != null && var.oci_config.subnet_id != null)
    error_message = "OCI config requires compartment_id, availability_domain, and subnet_id."
  }
}

# -----------------------------------------------------------------------------
# PROXMOX-SPECIFIC CONFIGURATION
# -----------------------------------------------------------------------------

variable "proxmox_config" {
  description = "Proxmox-specific configuration (required when provider_type = 'proxmox')"
  type = object({
    target_node    = string
    vmid           = number
    template_name  = optional(string)
    disk_storage   = optional(string)
    network_bridge = optional(string)
    existing       = optional(bool)
    qemu_agent     = optional(bool)
    gpu_passthrough = optional(object({
      pci_address = string
    }))
  })
  default = null

  validation {
    condition     = var.proxmox_config == null || (var.proxmox_config.target_node != null && var.proxmox_config.vmid != null)
    error_message = "Proxmox config requires target_node and vmid."
  }
}
