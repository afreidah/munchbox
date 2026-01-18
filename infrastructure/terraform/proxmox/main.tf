# -------------------------------------------------------------------------------
# Proxmox VM Provisioning - Nomad/Consul/Vault Cluster
#
# Project: Munchbox / Author: Alex Freidah
#
# Provisions Nomad server and client VMs on Proxmox by cloning a Debian base
# template. VM definitions come from nodes.yml via generated vms.auto.tfvars.
#
# Two additional Nomad servers run bare metal on Pi5s (stabler, goren) and are
# NOT managed by this Terraform - only by Ansible.
#
# Usage:
#   1. Edit infrastructure/nodes.yml to add/modify VMs
#   2. Run: make generate (creates vms.auto.tfvars)
#   3. Run: make tf-apply (provisions VMs)
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc05"
    }
  }

  backend "consul" {
    address = "stabler:8500"
    scheme  = "http"
    path    = "terraform/proxmox"
  }
}

# -------------------------------------------------------------------------------
# Provider Configuration
# -------------------------------------------------------------------------------

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_tls_insecure
}

# -------------------------------------------------------------------------------
# Locals
# -------------------------------------------------------------------------------

locals {
  template_name = var.template_name
  disk_storage  = var.vm_disk_storage
  net_bridge    = var.vm_network_bridge
}

# -------------------------------------------------------------------------------
# VMs (Dynamic - from nodes.yml via vms.auto.tfvars)
# -------------------------------------------------------------------------------

resource "proxmox_vm_qemu" "vm" {
  for_each    = var.vms
  name        = each.key
  target_node = each.value.target_node
  vmid        = each.value.vmid

  clone      = each.value.existing == true ? null : local.template_name
  full_clone = each.value.existing == true ? false : true

  memory = each.value.memory
  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }
  scsihw = "virtio-scsi-pci"
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = local.disk_storage
    size    = each.value.disk_size
  }
  network {
    id     = 0
    model  = "virtio"
    bridge = local.net_bridge
  }
  onboot = true
  agent  = 1

  # GPU passthrough support
  # Note: Requires IOMMU and VFIO configured on Proxmox host
  dynamic "hostpci" {
    for_each = each.value.gpu_passthrough != null ? [each.value.gpu_passthrough] : []
    content {
      host   = hostpci.value.pci_address
      pcie   = 1
      rombar = 1
    }
  }
}

# -------------------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------------------

output "vm_names" {
  description = "Names of provisioned VMs"
  value       = [for vm in proxmox_vm_qemu.vm : vm.name]
}

output "vm_details" {
  description = "VM details (name -> target_node)"
  value = {
    for name, vm in proxmox_vm_qemu.vm : name => {
      target_node = vm.target_node
      vmid        = vm.vmid
      memory      = vm.memory
      cores       = vm.cpu[0].cores
    }
  }
}
