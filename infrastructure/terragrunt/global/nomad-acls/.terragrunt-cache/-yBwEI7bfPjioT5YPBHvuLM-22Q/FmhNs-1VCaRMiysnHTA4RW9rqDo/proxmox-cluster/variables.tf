# -----------------------------------------------------------------------------
# PROXMOX CLUSTER MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

variable "vms" {
  description = "Map of VMs to provision"
  type = map(object({
    target_node     = string
    vmid            = number
    memory          = number
    cores           = number
    disk_size       = string
    existing        = optional(bool, false)
    onboot          = optional(bool, true)
    qemu_agent      = optional(bool, true)
    gpu_passthrough = optional(object({ pci_address = string }), null)
    cloud_init = optional(object({
      user       = optional(string, "root")
      ip         = string
      gateway    = string
      nameserver = optional(string)
      sshkeys    = optional(string)
    }), null)
  }))
}

variable "disk_storage" {
  description = "Proxmox storage ID for disks"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

variable "template_name" {
  description = "Template to clone from (for new VMs)"
  type        = string
  default     = "debian-base"
}
