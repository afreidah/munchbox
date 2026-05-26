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

  # Cloud-init CD-ROM drive. Only attached when `cloud_init.storage` is
  # set on the VM. Without this drive, ciuser / ipconfig0 / etc. live in
  # the VM config but never reach the guest -- so cloud_init.storage is
  # effectively required for any VM that relies on terraform-managed
  # cloud-init data.
  dynamic "disk" {
    for_each = try(each.value.cloud_init.storage, null) != null ? [each.value.cloud_init.storage] : []
    content {
      slot    = "ide2"
      type    = "cloudinit"
      storage = disk.value
    }
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

  # Cloud-init (optional). The actual CD-ROM drive is attached via the
  # dynamic disk block above (gated on `cloud_init.storage`). Without that
  # drive these settings are written to the VM config but never reach the
  # guest, so any VM relying on terraform-managed cloud-init data needs
  # `cloud_init.storage` set.
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

    # --- Stopgap: telmate's state disagrees with proxmox's actual layout on
    #     `disk` (slot/type ordering for the cloudinit drive) and silently
    #     drops `serial` / `startup_shutdown` blocks every refresh; `sshkeys`
    #     is a seed-only field (chef's sshd_ca recipe owns runtime keys).
    #     Cleaner long-term fix is to align state with reality via
    #     `terragrunt state` / targeted re-imports per resource. ---
    ignore_changes = [
      disk,
      serial,
      startup_shutdown,
      sshkeys,
      # --- pci: nomad-client-04 GPU passthrough is real on the VM but absent
      #     from state (predates the gpu_passthrough declaration). Adding it
      #     would cause a telmate-driven VM reboot to re-attach. ---
      pci,
    ]
  }
}
