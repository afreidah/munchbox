# -----------------------------------------------------------------------------
# PROXMOX CLUSTER MODULE
# -----------------------------------------------------------------------------
#
# Wrapper module that provisions multiple Proxmox VMs using for_each.
# Used for managing on-prem Nomad/Consul cluster nodes.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "proxmox_vm_qemu" "vm" {
  for_each = var.vms

  name        = each.key
  target_node = each.value.target_node
  vmid        = each.value.vmid

  # Clone configuration
  clone      = try(each.value.existing, false) ? null : var.template_name
  full_clone = try(each.value.existing, false) ? false : true

  # Compute resources
  memory = each.value.memory
  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }

  # Storage
  scsihw = "virtio-scsi-pci"
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.disk_storage
    size    = each.value.disk_size
  }

  # Networking
  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Boot and agent
  onboot = try(each.value.onboot, true)
  agent  = try(each.value.qemu_agent, true) ? 1 : 0

  # Cloud-init (optional)
  ciuser     = try(each.value.cloud_init.user, null)
  ipconfig0  = try(each.value.cloud_init, null) != null ? "ip=${each.value.cloud_init.ip},gw=${each.value.cloud_init.gateway}" : null
  nameserver = try(each.value.cloud_init.nameserver, null)
  sshkeys    = try(each.value.cloud_init.sshkeys, null)

  # GPU passthrough (optional)
  dynamic "pci" {
    for_each = try(each.value.gpu_passthrough, null) != null ? [each.value.gpu_passthrough] : []
    content {
      id     = "0"
      raw_id = pci.value.pci_address
      pcie   = true
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}
