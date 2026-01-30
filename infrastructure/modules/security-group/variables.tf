# -----------------------------------------------------------------------------
# SECURITY GROUP MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name of the security group"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "Name must be between 1 and 64 characters."
  }
}

variable "description" {
  description = "Description of the security group"
  type        = string
  default     = "Managed by Terraform"
}

variable "vpc_id" {
  description = "ID of the VPC where security group will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must start with 'vpc-'."
  }
}

variable "ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr        = string
    description = string
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.ingress_rules :
      rule.from_port >= -1 && rule.from_port <= 65535
    ])
    error_message = "Ingress from_port must be between -1 and 65535."
  }

  validation {
    condition = alltrue([
      for rule in var.ingress_rules :
      rule.to_port >= -1 && rule.to_port <= 65535
    ])
    error_message = "Ingress to_port must be between -1 and 65535."
  }

  validation {
    condition = alltrue([
      for rule in var.ingress_rules :
      can(cidrhost(rule.cidr, 0))
    ])
    error_message = "Ingress CIDR must be valid CIDR notation."
  }
}

variable "egress_rules" {
  description = "List of egress rules"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr        = string
    description = string
  }))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr        = "0.0.0.0/0"
      description = "Allow all outbound"
    }
  ]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# PRESET VARIABLES - Common homelab patterns
# -----------------------------------------------------------------------------

variable "allow_ssh" {
  description = "Allow SSH from specified CIDR (set to null to disable)"
  type        = string
  default     = null
}

variable "allow_wireguard" {
  description = "Allow WireGuard (UDP 51820) from specified CIDR (set to null to disable)"
  type        = string
  default     = null
}

variable "trusted_cidr" {
  description = "CIDR block for trusted network (e.g., WireGuard subnet) - allows all traffic"
  type        = string
  default     = null
}

variable "allow_icmp" {
  description = "Allow ICMP (ping) from specified CIDR (set to null to disable)"
  type        = string
  default     = null
}
