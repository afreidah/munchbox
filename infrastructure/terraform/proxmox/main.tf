# -------------------------------------------------------------------------------
# Proxmox VM Provisioning - Main Configuration
#
# Project: Munchbox / Author: Alex Freidah
#
# Provisions Nomad cluster VMs on Proxmox with cloud-init bootstrap. Creates
# Nomad servers on fontana and distributes clients across the cluster.
# Assumes Proxmox VE is already installed from ISO.
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
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
# Nomad Server VMs (3x on fontana)
# -------------------------------------------------------------------------------

resource "proxmox_vm_qemu" "nomad_servers" {
  count = 3
  
  name        = "nomad-server-${format("%02d", count.index + 1)}"
  target_node = "fontana"
  vmid        = 170 + count.index
  
  clone      = var.template_name
  full_clone = true
  
  cores   = 2
  sockets = 1
  memory  = 4096
  
  scsihw = "virtio-scsi-single"
  
  # --- Boot Disk (Ceph)
  
  disks {
    scsi {
      scsi0 {
        disk {
          size    = "40G"
          storage = "ceph-rbd"
        }
      }
    }
  }
  
  # --- Network
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  ipconfig0 = "ip=192.168.68.${70 + count.index}/24,gw=192.168.68.1"
  
  # --- Cloud-Init
  
  os_type = "cloud-init"
  
  ciuser     = var.ansible_user
  cipassword = var.ansible_password
  sshkeys    = var.ssh_public_key
  
  cicustom = "user=local:snippets/cloud-init-nomad-server.yml"
  
  # --- Lifecycle
  
  onboot  = true
  agent   = 1
  
  lifecycle {
    ignore_changes = [
      network,
      ipconfig0,
      ciuser,
      sshkeys,
    ]
  }
}

# -------------------------------------------------------------------------------
# Nomad Client VMs (x86_64)
# -------------------------------------------------------------------------------

# --- Client 01 (cabot)

resource "proxmox_vm_qemu" "nomad_client_01" {
  name        = "nomad-client-01"
  target_node = "cabot"
  vmid        = 180
  
  clone      = var.template_name
  full_clone = true
  
  cores   = 4
  sockets = 1
  memory  = 6144
  
  scsihw = "virtio-scsi-single"
  
  disks {
    scsi {
      scsi0 {
        disk {
          size    = "80G"
          storage = "ceph-rbd"
        }
      }
    }
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  ipconfig0 = "ip=192.168.68.80/24,gw=192.168.68.1"
  
  os_type = "cloud-init"
  
  ciuser     = var.ansible_user
  cipassword = var.ansible_password
  sshkeys    = var.ssh_public_key
  
  cicustom = "user=local:snippets/cloud-init-nomad-client.yml"
  
  onboot = true
  agent  = 1
  
  lifecycle {
    ignore_changes = [
      network,
      ipconfig0,
      ciuser,
      sshkeys,
    ]
  }
}

# --- Client 02 (mccoy)

resource "proxmox_vm_qemu" "nomad_client_02" {
  name        = "nomad-client-02"
  target_node = "mccoy"
  vmid        = 181
  
  clone      = var.template_name
  full_clone = true
  
  cores   = 6
  sockets = 1
  memory  = 12288
  
  scsihw = "virtio-scsi-single"
  
  disks {
    scsi {
      scsi0 {
        disk {
          size    = "80G"
          storage = "ceph-rbd"
        }
      }
    }
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  ipconfig0 = "ip=192.168.68.81/24,gw=192.168.68.1"
  
  os_type = "cloud-init"
  
  ciuser     = var.ansible_user
  cipassword = var.ansible_password
  sshkeys    = var.ssh_public_key
  
  cicustom = "user=local:snippets/cloud-init-nomad-client.yml"
  
  onboot = true
  agent  = 1
  
  lifecycle {
    ignore_changes = [
      network,
      ipconfig0,
      ciuser,
      sshkeys,
    ]
  }
}

# --- Client 03 (fontana)

resource "proxmox_vm_qemu" "nomad_client_03" {
  name        = "nomad-client-03"
  target_node = "fontana"
  vmid        = 182
  
  clone      = var.template_name
  full_clone = true
  
  cores   = 8
  sockets = 1
  memory  = 16384
  
  scsihw = "virtio-scsi-single"
  
  disks {
    scsi {
      scsi0 {
        disk {
          size    = "100G"
          storage = "ceph-rbd"
        }
      }
    }
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  ipconfig0 = "ip=192.168.68.82/24,gw=192.168.68.1"
  
  os_type = "cloud-init"
  
  ciuser     = var.ansible_user
  cipassword = var.ansible_password
  sshkeys    = var.ssh_public_key
  
  cicustom = "user=local:snippets/cloud-init-nomad-client.yml"
  
  onboot = true
  agent  = 1
  
  lifecycle {
    ignore_changes = [
      network,
      ipconfig0,
      ciuser,
      sshkeys,
    ]
  }
}

# --- Client 04 (fontana)

resource "proxmox_vm_qemu" "nomad_client_04" {
  name        = "nomad-client-04"
  target_node = "fontana"
  vmid        = 183
  
  clone      = var.template_name
  full_clone = true
  
  cores   = 6
  sockets = 1
  memory  = 10240
  
  scsihw = "virtio-scsi-single"
  
  disks {
    scsi {
      scsi0 {
        disk {
          size    = "80G"
          storage = "ceph-rbd"
        }
      }
    }
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  ipconfig0 = "ip=192.168.68.83/24,gw=192.168.68.1"
  
  os_type = "cloud-init"
  
  ciuser     = var.ansible_user
  cipassword = var.ansible_password
  sshkeys    = var.ssh_public_key
  
  cicustom = "user=local:snippets/cloud-init-nomad-client.yml"
  
  onboot = true
  agent  = 1
  
  lifecycle {
    ignore_changes = [
      network,
      ipconfig0,
      ciuser,
      sshkeys,
    ]
  }
}
