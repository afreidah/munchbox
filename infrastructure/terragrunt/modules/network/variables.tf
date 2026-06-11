# -----------------------------------------------------------------------------
# UNIFIED NETWORK MODULE - VARIABLES
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
  description = "Name prefix for network resources"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 32
    error_message = "Name must be between 1 and 32 characters."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC/VCN"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be valid CIDR notation."
  }
}

variable "subnet_cidr" {
  description = "CIDR block for primary subnet (OCI only, AWS auto-calculates)"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "Subnet CIDR must be valid CIDR notation."
  }
}

variable "tags" {
  description = "Tags to apply to resources (where supported)"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# SECURITY PRESETS (Applied to security group/list)
# -----------------------------------------------------------------------------

variable "allow_ssh" {
  description = "Allow SSH from specified CIDR (null to disable)"
  type        = string
  default     = null
}

variable "allow_wireguard" {
  description = "Allow WireGuard (UDP 51820) from specified CIDR (null to disable)"
  type        = string
  default     = null
}

variable "allow_icmp" {
  description = "Allow ICMP (ping) from specified CIDR (null to disable)"
  type        = string
  default     = null
}

variable "trusted_cidr" {
  description = "CIDR for trusted network - allows all TCP/UDP (e.g., WireGuard subnet)"
  type        = string
  default     = null
}

variable "additional_ingress_rules" {
  description = "Additional custom ingress rules (AWS format)"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr        = string
    description = string
  }))
  default = []
}

variable "oci_ingress_rules" {
  description = "Additional custom ingress rules for the OCI security list (OCI format)"
  type = list(object({
    protocol    = string
    source      = string
    description = string
    port_min    = optional(number)
    port_max    = optional(number)
  }))
  default = []
}

# -----------------------------------------------------------------------------
# AWS-SPECIFIC CONFIGURATION
# -----------------------------------------------------------------------------

variable "aws_config" {
  description = "AWS-specific configuration (required when provider_type = 'aws')"
  type = object({
    availability_zones = list(string)
    subnet_newbits     = optional(number) # Bits to add to VPC CIDR for subnets
  })
  default = null

  validation {
    condition     = var.aws_config == null || length(var.aws_config.availability_zones) > 0
    error_message = "AWS config requires at least one availability zone."
  }
}

# -----------------------------------------------------------------------------
# OCI-SPECIFIC CONFIGURATION
# -----------------------------------------------------------------------------

variable "oci_config" {
  description = "OCI-specific configuration (required when provider_type = 'oci')"
  type = object({
    compartment_id   = string
    dns_label        = optional(string)
    subnet_dns_label = optional(string)
  })
  default = null

  validation {
    condition     = var.oci_config == null || var.oci_config.compartment_id != null
    error_message = "OCI config requires compartment_id."
  }
}

# -----------------------------------------------------------------------------
# PROXMOX-SPECIFIC CONFIGURATION
# -----------------------------------------------------------------------------

variable "proxmox_config" {
  description = "Proxmox-specific configuration (references existing network bridge)"
  type = object({
    network_bridge = optional(string) # Default: vmbr0
    network_cidr   = optional(string) # For documentation, default: 192.168.68.0/24
  })
  default = null
}
