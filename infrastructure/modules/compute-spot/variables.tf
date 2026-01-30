# -----------------------------------------------------------------------------
# COMPUTE SPOT MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name for the instance and related resources"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "Name must be between 1 and 64 characters."
  }
}

variable "subnet_id" {
  description = "ID of the subnet to launch the instance in"
  type        = string

  validation {
    condition     = can(regex("^subnet-", var.subnet_id))
    error_message = "Subnet ID must start with 'subnet-'."
  }
}

variable "security_group_ids" {
  description = "List of security group IDs to attach"
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one security group ID is required."
  }
}

# -----------------------------------------------------------------------------
# INSTANCE CONFIGURATION
# -----------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.medium"
}

variable "architecture" {
  description = "CPU architecture: arm64 (Graviton) or x86_64"
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "Architecture must be 'arm64' or 'x86_64'."
  }
}

variable "ami_id" {
  description = "Specific AMI ID to use (overrides automatic lookup)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# SPOT CONFIGURATION
# -----------------------------------------------------------------------------

variable "spot_type" {
  description = "Spot request type: one-time or persistent"
  type        = string
  default     = "persistent"

  validation {
    condition     = contains(["one-time", "persistent"], var.spot_type)
    error_message = "Spot type must be 'one-time' or 'persistent'."
  }
}

variable "interruption_behavior" {
  description = "Behavior on spot interruption: stop, terminate, or hibernate"
  type        = string
  default     = "stop"

  validation {
    condition     = contains(["stop", "terminate", "hibernate"], var.interruption_behavior)
    error_message = "Interruption behavior must be 'stop', 'terminate', or 'hibernate'."
  }
}

variable "wait_for_fulfillment" {
  description = "Wait for spot request to be fulfilled before completing"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# STORAGE CONFIGURATION
# -----------------------------------------------------------------------------

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 16384
    error_message = "Root volume size must be between 8 and 16384 GB."
  }
}

variable "root_volume_type" {
  description = "Type of root volume: gp3, gp2, io1, io2"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "gp2", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be gp3, gp2, io1, or io2."
  }
}

variable "encrypt_root_volume" {
  description = "Encrypt the root volume"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# SSH CONFIGURATION
# -----------------------------------------------------------------------------

variable "ssh_public_key" {
  description = "SSH public key to create a new key pair (mutually exclusive with key_name)"
  type        = string
  default     = null
}

variable "key_name" {
  description = "Name of existing key pair to use (mutually exclusive with ssh_public_key)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# NETWORKING
# -----------------------------------------------------------------------------

variable "assign_elastic_ip" {
  description = "Assign an Elastic IP for a static public address"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# BOOTSTRAPPING
# -----------------------------------------------------------------------------

variable "user_data" {
  description = "User data script for instance bootstrapping"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# TAGGING
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
