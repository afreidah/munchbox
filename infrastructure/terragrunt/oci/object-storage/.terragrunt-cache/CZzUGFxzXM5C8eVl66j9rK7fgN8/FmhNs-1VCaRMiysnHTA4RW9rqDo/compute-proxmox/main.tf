# -----------------------------------------------------------------------------
# COMPUTE MODULE - PROXMOX
# -----------------------------------------------------------------------------
#
# Provisions VMs on Proxmox by cloning a base template.
#
# Features:
#   - Clone from template or import existing VM
#   - Configurable CPU cores, memory, disk
#   - VirtIO networking and SCSI storage
#   - QEMU guest agent support
#
# Note: Unlike cloud providers, Proxmox VMs get IPs from local network
# (DHCP or static). IPs are retrieved via QEMU guest agent after boot.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
    }
  }
}

# -----------------------------------------------------------------------------
# VM RESOURCE
# -----------------------------------------------------------------------------

resource "proxmox_vm_qemu" "this" {
  name        = var.name
  target_node = var.target_node
  vmid        = var.vmid

  # Clone configuration
  clone      = var.existing ? null : var.template_name
  full_clone = var.existing ? false : true

  # Compute resources
  memory = var.memory_mb
  cpu {
    cores   = var.cores
    sockets = var.sockets
    type    = var.cpu_type
  }

  # Storage
  scsihw = "virtio-scsi-pci"
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.disk_storage
    size    = var.disk_size
  }

  # Networking
  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Boot and agent
  onboot = var.onboot
  agent  = var.qemu_agent ? 1 : 0

  # GPU passthrough (optional)
  dynamic "hostpci" {
    for_each = var.gpu_passthrough != null ? [var.gpu_passthrough] : []
    content {
      host   = hostpci.value.pci_address
      pcie   = true
      rombar = true
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}
