# -----------------------------------------------------------------------------
# COMPUTE MODULE (PROXMOX) - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name of the VM"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "Name must be between 1 and 64 characters."
  }
}

variable "target_node" {
  description = "Proxmox node to create the VM on"
  type        = string
}

variable "vmid" {
  description = "VM ID (must be unique across cluster)"
  type        = number

  validation {
    condition     = var.vmid >= 100 && var.vmid <= 999999999
    error_message = "VMID must be between 100 and 999999999."
  }
}

# -----------------------------------------------------------------------------
# COMPUTE RESOURCES
# -----------------------------------------------------------------------------

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2

  validation {
    condition     = var.cores >= 1 && var.cores <= 128
    error_message = "Cores must be between 1 and 128."
  }
}

variable "sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "cpu_type" {
  description = "CPU type (host for passthrough, or specific model)"
  type        = string
  default     = "host"
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
  default     = 2048

  validation {
    condition     = var.memory_mb >= 512
    error_message = "Memory must be at least 512 MB."
  }
}

# -----------------------------------------------------------------------------
# STORAGE
# -----------------------------------------------------------------------------

variable "disk_size" {
  description = "Disk size (e.g., '32G', '100G')"
  type        = string
  default     = "32G"

  validation {
    condition     = can(regex("^[0-9]+[GM]$", var.disk_size))
    error_message = "Disk size must match pattern like '32G' or '4096M'."
  }
}

variable "disk_storage" {
  description = "Proxmox storage ID for disk"
  type        = string
  default     = "local-lvm"
}

# -----------------------------------------------------------------------------
# TEMPLATE / CLONE
# -----------------------------------------------------------------------------

variable "template_name" {
  description = "Name of the template to clone from"
  type        = string
  default     = "debian-base"
}

variable "existing" {
  description = "Import existing VM instead of cloning (skip clone)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# NETWORKING
# -----------------------------------------------------------------------------

variable "network_bridge" {
  description = "Network bridge to attach VM to"
  type        = string
  default     = "vmbr0"
}

# -----------------------------------------------------------------------------
# BOOT AND AGENT
# -----------------------------------------------------------------------------

variable "onboot" {
  description = "Start VM on Proxmox host boot"
  type        = bool
  default     = true
}

variable "qemu_agent" {
  description = "Enable QEMU guest agent"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# GPU PASSTHROUGH (OPTIONAL)
# -----------------------------------------------------------------------------

variable "gpu_passthrough" {
  description = "GPU passthrough configuration"
  type = object({
    pci_address = string
  })
  default = null
}
