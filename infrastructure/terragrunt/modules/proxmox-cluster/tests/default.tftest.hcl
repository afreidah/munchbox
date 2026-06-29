# -----------------------------------------------------------------------------
# proxmox-cluster module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the vms-map for_each fan-out, the existing-vs-new clone/full_clone
# gating per-VM, the dynamic disk block for cloudinit (only renders when
# cloud_init.storage is set), and the dynamic pci block (only renders when
# gpu_passthrough is set).
# -----------------------------------------------------------------------------

mock_provider "proxmox" {}

variables {
  template_name  = "debian-base"
  disk_storage   = "local-lvm"
  network_bridge = "vmbr0"
  vms = {
    "fresh-vm" = {
      target_node = "node1"
      vmid        = 100
      memory      = 2048
      cores       = 2
      disk_size   = "20G"
    }
    "existing-vm" = {
      target_node = "node2"
      vmid        = 101
      memory      = 4096
      cores       = 4
      disk_size   = "40G"
      existing    = true
    }
    "cloud-init-vm" = {
      target_node = "node3"
      vmid        = 102
      memory      = 2048
      cores       = 2
      disk_size   = "20G"
      cloud_init = {
        ip         = "192.168.1.10/24"
        gateway    = "192.168.1.1"
        nameserver = "1.1.1.1"
        storage    = "local-lvm"
      }
    }
    "gpu-vm" = {
      target_node     = "node4"
      vmid            = 103
      memory          = 16384
      cores           = 8
      disk_size       = "60G"
      gpu_passthrough = { pci_address = "0000:01:00.0" }
    }
  }
}

# -------------------------------------------------------------------------
# vms map fans out 1:1
# -------------------------------------------------------------------------

run "vms_for_each" {
  command = plan

  # --- four VMs in input -> four resources ---
  assert {
    condition     = length(proxmox_vm_qemu.vm) == 4
    error_message = "four VMs in input -> four resources"
  }

  # --- fresh-vm key exists in the for_each map ---
  assert {
    condition     = contains(keys(proxmox_vm_qemu.vm), "fresh-vm")
    error_message = "fresh-vm key must exist"
  }

  # --- output vms map keys on every input VM ---
  assert {
    condition     = toset(keys(output.vms)) == toset(["fresh-vm", "existing-vm", "cloud-init-vm", "gpu-vm"])
    error_message = "vms output must key on every input VM"
  }

  # --- output vms entries echo their input scalars ---
  assert {
    condition     = output.vms["fresh-vm"].memory == 2048 && output.vms["fresh-vm"].cores == 2
    error_message = "vms output must echo per-VM memory + cores"
  }

  # --- output vm_names lists every VM name ---
  assert {
    condition     = toset(output.vm_names) == toset(["fresh-vm", "existing-vm", "cloud-init-vm", "gpu-vm"])
    error_message = "vm_names output must list every VM name"
  }
}

# -------------------------------------------------------------------------
# Fresh VM: clone = template, full_clone = true
# -------------------------------------------------------------------------

run "fresh_vm_clones_template" {
  command = plan

  # --- clone source = configured template ---
  assert {
    condition     = proxmox_vm_qemu.vm["fresh-vm"].clone == var.template_name
    error_message = "fresh VM should clone configured template"
  }

  # --- full_clone = true (not linked) ---
  assert {
    condition     = proxmox_vm_qemu.vm["fresh-vm"].full_clone == true
    error_message = "fresh VM should do a full_clone"
  }
}

# -------------------------------------------------------------------------
# Existing VM: clone = null, full_clone = false
# -------------------------------------------------------------------------

run "existing_vm_skips_clone" {
  command = plan

  # --- existing = true suppresses clone ---
  assert {
    condition     = proxmox_vm_qemu.vm["existing-vm"].clone == null
    error_message = "existing = true should suppress clone"
  }

  # --- existing = true suppresses full_clone ---
  assert {
    condition     = proxmox_vm_qemu.vm["existing-vm"].full_clone == false
    error_message = "existing = true should suppress full_clone"
  }
}

# -------------------------------------------------------------------------
# Cloudinit dynamic disk: only fires when cloud_init.storage is set
# -------------------------------------------------------------------------

run "cloudinit_disk_dynamic" {
  command = plan

  # --- VM without cloud_init.storage -> only primary disk (length 1) ---
  assert {
    condition     = length(proxmox_vm_qemu.vm["fresh-vm"].disk) == 1
    error_message = "VM without cloud_init.storage should have only primary disk"
  }

  # --- VM with cloud_init.storage -> primary + cloudinit CD disks (length 2) ---
  assert {
    condition     = length(proxmox_vm_qemu.vm["cloud-init-vm"].disk) == 2
    error_message = "VM with cloud_init.storage should have primary + cloudinit disks"
  }
}

# -------------------------------------------------------------------------
# GPU passthrough dynamic pci block: only when gpu_passthrough set
# -------------------------------------------------------------------------

run "gpu_passthrough_dynamic" {
  command = plan

  # --- VM without gpu_passthrough has no pci block ---
  assert {
    condition     = length(proxmox_vm_qemu.vm["fresh-vm"].pci) == 0
    error_message = "VM without gpu_passthrough should have no pci block"
  }

  # --- VM with gpu_passthrough has one pci block ---
  assert {
    condition     = length(proxmox_vm_qemu.vm["gpu-vm"].pci) == 1
    error_message = "VM with gpu_passthrough should have one pci block"
  }

  # --- gpu_passthrough.pci_address flows to pci[0].raw_id ---
  assert {
    condition     = proxmox_vm_qemu.vm["gpu-vm"].pci[0].raw_id == "0000:01:00.0"
    error_message = "gpu_passthrough.pci_address should flow to pci.raw_id"
  }
}

# -------------------------------------------------------------------------
# ipconfig0 only set when cloud_init is provided
# -------------------------------------------------------------------------

run "ipconfig0_conditional" {
  command = plan

  # --- no cloud_init -> ipconfig0 is null ---
  assert {
    condition     = proxmox_vm_qemu.vm["fresh-vm"].ipconfig0 == null
    error_message = "no cloud_init -> ipconfig0 must be null"
  }

  # --- cloud_init.ip + .gateway compose into ipconfig0 ---
  assert {
    condition     = proxmox_vm_qemu.vm["cloud-init-vm"].ipconfig0 == "ip=192.168.1.10/24,gw=192.168.1.1"
    error_message = "cloud_init.ip + .gateway must compose into ipconfig0"
  }
}

# -------------------------------------------------------------------------
# Empty vms map: zero resources, no errors
# -------------------------------------------------------------------------

run "empty_vms" {
  command = plan

  variables {
    vms = {}
  }

  # --- empty vms map -> zero VM resources ---
  assert {
    condition     = length(proxmox_vm_qemu.vm) == 0
    error_message = "empty vms map -> zero resources"
  }
}
