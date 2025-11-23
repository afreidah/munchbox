# -------------------------------------------------------------------------------
# Proxmox VM Provisioning - Nomad/Consul/Vault Cluster
#
# Project: Munchbox / Author: Alex Freidah
#
# Provisions Nomad server and client VMs on Proxmox by cloning a Debian base
# template. Two additional Nomad servers run bare metal on Pi5s (stabler, goren).
# Optimized for hardware constraints: fontana/mccoy 16GB, cabot 8GB.
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
  template_name = var.template_name
  disk_storage  = var.vm_disk_storage
  net_bridge    = var.vm_network_bridge
}

# -------------------------------------------------------------------------------
# Nomad Server VM (1x on fontana)
# -------------------------------------------------------------------------------

resource "proxmox_vm_qemu" "nomad_server" {
  name        = "nomad-server-03"
  target_node = "fontana"
  vmid        = 172

  clone      = local.template_name
  full_clone = true

  memory = 2048

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
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

# -------------------------------------------------------------------------------
# Nomad Client VMs (x86_64)
# -------------------------------------------------------------------------------

# --- Client 01 (fontana) ---

resource "proxmox_vm_qemu" "nomad_client_01" {
  name        = "nomad-client-01"
  target_node = "fontana"
  vmid        = 180

  clone      = local.template_name
  full_clone = true

  memory = 13312

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
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

  memory = 15360

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
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

# --- Client 03 (cabot) ---

resource "proxmox_vm_qemu" "nomad_client_03" {
  name        = "nomad-client-03"
  target_node = "cabot"
  vmid        = 182

  clone      = local.template_name
  full_clone = true

  memory = 7168

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
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
