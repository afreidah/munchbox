# -----------------------------------------------------------------------------
# compute-proxmox module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the existing-vs-new VM gating: var.existing = true short-circuits
# clone (= null) and full_clone (= false); var.existing = false clones from
# var.template_name with full_clone = true. Also verifies basic shape: vmid,
# memory propagate, and the primary disk uses scsi0.
# -----------------------------------------------------------------------------

mock_provider "proxmox" {}

variables {
  name          = "test-vm"
  target_node   = "test-node"
  vmid          = 999
  cores         = 4
  memory_mb     = 8192
  disk_size     = "40G"
  disk_storage  = "local-lvm"
  template_name = "ubuntu-base"
}

# -------------------------------------------------------------------------
# New VM: existing=false -> clone from template, full_clone = true
# -------------------------------------------------------------------------

run "new_vm_clones_template" {
  command = plan

  variables {
    existing = false
  }

  # --- clone source comes from var.template_name ---
  assert {
    condition     = proxmox_vm_qemu.this.clone == var.template_name
    error_message = "new VM should clone the configured template"
  }

  # --- full clone (not linked) ---
  assert {
    condition     = proxmox_vm_qemu.this.full_clone == true
    error_message = "new VM should request a full_clone"
  }
}

# -------------------------------------------------------------------------
# Existing VM: existing=true -> clone = null, full_clone = false
# -------------------------------------------------------------------------

run "existing_vm_skips_clone" {
  command = plan

  variables {
    existing = true
  }

  # --- clone is null (don't clone, the VM already exists) ---
  assert {
    condition     = proxmox_vm_qemu.this.clone == null
    error_message = "existing VM must NOT trigger a clone"
  }

  # --- full_clone false (no replication action) ---
  assert {
    condition     = proxmox_vm_qemu.this.full_clone == false
    error_message = "existing VM must NOT request a full_clone"
  }
}

# -------------------------------------------------------------------------
# Compute shape (vmid, memory) propagates from vars
# -------------------------------------------------------------------------

run "compute_shape_propagates" {
  command = plan

  # --- vmid flows to the resource ---
  assert {
    condition     = proxmox_vm_qemu.this.vmid == var.vmid
    error_message = "vmid must propagate"
  }

  # --- memory_mb flows to the resource ---
  assert {
    condition     = proxmox_vm_qemu.this.memory == var.memory_mb
    error_message = "memory_mb must propagate"
  }
}

# -------------------------------------------------------------------------
# Primary disk uses scsi0 slot, storage backend from var
# -------------------------------------------------------------------------

run "storage_scsi0" {
  command = plan

  # --- primary disk slot is scsi0 ---
  assert {
    condition     = proxmox_vm_qemu.this.disk[0].slot == "scsi0"
    error_message = "primary disk must use scsi0 slot"
  }

  # --- storage backend propagates from var ---
  assert {
    condition     = proxmox_vm_qemu.this.disk[0].storage == var.disk_storage
    error_message = "disk storage backend must propagate"
  }
}
