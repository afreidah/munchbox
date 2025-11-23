# -------------------------------------------------------------------------------
# Proxmox VM Provisioning - Nomad/Consul/Vault Base Cluster
#
# Project: Munchbox / Author: Alex Freidah
#
# Provisions Nomad server and client VMs on Proxmox by cloning a Debian base
# template built on local-lvm. Removes prior Ceph and cloud-init dependencies
# and relies on root SSH keys and Ansible for configuration.
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc05"
    }
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
  # Template VM name to clone (backed by VMID 100)
  template_name = var.template_name

  # Storage and network configuration
  disk_storage = var.vm_disk_storage   # local-lvm
  net_bridge   = var.vm_network_bridge # vmbr0
}

# -------------------------------------------------------------------------------
# Nomad Server VMs (3x on fontana)
# -------------------------------------------------------------------------------

resource "proxmox_vm_qemu" "nomad_servers" {
  count = 3

  name        = "nomad-server-${format("%02d", count.index + 1)}"
  target_node = "fontana"
  vmid        = 170 + count.index

  clone      = local.template_name
  full_clone = true

  memory = 4096

  cpu {
    cores   = 2
    sockets = 1
  }

  scsihw = "virtio-scsi-pci"

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = local.disk_storage
    size    = "40G"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = local.net_bridge
  }

  # No cloud-init configuration. Networking assumed via DHCP or external config.

  onboot = true
  agent  = 1
}

# -------------------------------------------------------------------------------
# Nomad Client VMs (x86_64)
# -------------------------------------------------------------------------------

# --- Client 01 (cabot) ---

resource "proxmox_vm_qemu" "nomad_client_01" {
  name        = "nomad-client-01"
  target_node = "cabot"
  vmid        = 180

  clone      = local.template_name
  full_clone = true

  memory = 6144

  cpu {
    cores   = 4
    sockets = 1
  }

  scsihw = "virtio-scsi-pci"

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = local.disk_storage
    size    = "40G"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = local.net_bridge
  }

  onboot = true
  agent  = 1
}

# --- Client 02 (mccoy) ---

resource "proxmox_vm_qemu" "nomad_client_02" {
  name        = "nomad-client-02"
  target_node = "mccoy"
  vmid        = 181

  clone      = local.template_name
  full_clone = true

  memory = 12288

  cpu {
    cores   = 6
    sockets = 1
  }

  scsihw = "virtio-scsi-pci"

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = local.disk_storage
    size    = "40G"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = local.net_bridge
  }

  onboot = true
  agent  = 1
}

# --- Client 03 (fontana) ---

resource "proxmox_vm_qemu" "nomad_client_03" {
  name        = "nomad-client-03"
  target_node = "fontana"
  vmid        = 182

  clone      = local.template_name
  full_clone = true

  memory = 16384

  cpu {
    cores   = 8
    sockets = 1
  }

  scsihw = "virtio-scsi-pci"

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = local.disk_storage
    size    = "40G"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = local.net_bridge
  }

  onboot = true
  agent  = 1
}

# --- Client 04 (fontana) ---

resource "proxmox_vm_qemu" "nomad_client_04" {
  name        = "nomad-client-04"
  target_node = "fontana"
  vmid        = 183

  clone      = local.template_name
  full_clone = true

  memory = 10240

  cpu {
    cores   = 6
    sockets = 1
  }

  scsihw = "virtio-scsi-pci"

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = local.disk_storage
    size    = "40G"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = local.net_bridge
  }

  onboot = true
  agent  = 1
}

