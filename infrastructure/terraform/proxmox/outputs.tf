# -------------------------------------------------------------------------------
# Proxmox VM Provisioning - Outputs
#
# Project: Munchbox / Author: Alex Freidah
#
# Exposes VM metadata for downstream automation. IP assignment is managed
# externally (DHCP or static configuration) and is not derived from Terraform.
# This avoids deprecated attributes in the Proxmox provider schema.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Nomad Servers
# -------------------------------------------------------------------------------

output "nomad_servers" {
  description = "Nomad server VM metadata"
  value = {
    for vm in proxmox_vm_qemu.nomad_servers :
    vm.name => {
      vmid   = vm.vmid
      node   = vm.target_node
      memory = vm.memory
    }
  }
}

# -------------------------------------------------------------------------------
# Nomad Clients
# -------------------------------------------------------------------------------

output "nomad_clients" {
  description = "Nomad client VM metadata"
  value = {
    "nomad-client-01" = {
      vmid   = proxmox_vm_qemu.nomad_client_01.vmid
      node   = proxmox_vm_qemu.nomad_client_01.target_node
      memory = proxmox_vm_qemu.nomad_client_01.memory
    }
    "nomad-client-02" = {
      vmid   = proxmox_vm_qemu.nomad_client_02.vmid
      node   = proxmox_vm_qemu.nomad_client_02.target_node
      memory = proxmox_vm_qemu.nomad_client_02.memory
    }
    "nomad-client-03" = {
      vmid   = proxmox_vm_qemu.nomad_client_03.vmid
      node   = proxmox_vm_qemu.nomad_client_03.target_node
      memory = proxmox_vm_qemu.nomad_client_03.memory
    }
    "nomad-client-04" = {
      vmid   = proxmox_vm_qemu.nomad_client_04.vmid
      node   = proxmox_vm_qemu.nomad_client_04.target_node
      memory = proxmox_vm_qemu.nomad_client_04.memory
    }
  }
}
