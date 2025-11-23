# -------------------------------------------------------------------------------
# Proxmox VM Provisioning - Outputs
#
# Project: Munchbox / Author: Alex Freidah
#
# Exports VM information for use by Ansible dynamic inventory and other
# downstream automation.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Nomad Servers
# -------------------------------------------------------------------------------

output "nomad_servers" {
  description = "Nomad server VM details"
  value = {
    for idx, vm in proxmox_vm_qemu.nomad_servers : vm.name => {
      vmid      = vm.vmid
      node      = vm.target_node
      ip        = split("/", vm.ipconfig0)[0]
      cores     = vm.cores
      memory    = vm.memory
      disk_size = vm.disks.0.scsi.scsi0.disk.0.size
    }
  }
}

# -------------------------------------------------------------------------------
# Nomad Clients
# -------------------------------------------------------------------------------

output "nomad_clients" {
  description = "Nomad client VM details"
  value = {
    nomad-client-01 = {
      vmid      = proxmox_vm_qemu.nomad_client_01.vmid
      node      = proxmox_vm_qemu.nomad_client_01.target_node
      ip        = split("/", proxmox_vm_qemu.nomad_client_01.ipconfig0)[0]
      cores     = proxmox_vm_qemu.nomad_client_01.cores
      memory    = proxmox_vm_qemu.nomad_client_01.memory
      disk_size = proxmox_vm_qemu.nomad_client_01.disks.0.scsi.scsi0.disk.0.size
    }
    nomad-client-02 = {
      vmid      = proxmox_vm_qemu.nomad_client_02.vmid
      node      = proxmox_vm_qemu.nomad_client_02.target_node
      ip        = split("/", proxmox_vm_qemu.nomad_client_02.ipconfig0)[0]
      cores     = proxmox_vm_qemu.nomad_client_02.cores
      memory    = proxmox_vm_qemu.nomad_client_02.memory
      disk_size = proxmox_vm_qemu.nomad_client_02.disks.0.scsi.scsi0.disk.0.size
    }
    nomad-client-03 = {
      vmid      = proxmox_vm_qemu.nomad_client_03.vmid
      node      = proxmox_vm_qemu.nomad_client_03.target_node
      ip        = split("/", proxmox_vm_qemu.nomad_client_03.ipconfig0)[0]
      cores     = proxmox_vm_qemu.nomad_client_03.cores
      memory    = proxmox_vm_qemu.nomad_client_03.memory
      disk_size = proxmox_vm_qemu.nomad_client_03.disks.0.scsi.scsi0.disk.0.size
    }
    nomad-client-04 = {
      vmid      = proxmox_vm_qemu.nomad_client_04.vmid
      node      = proxmox_vm_qemu.nomad_client_04.target_node
      ip        = split("/", proxmox_vm_qemu.nomad_client_04.ipconfig0)[0]
      cores     = proxmox_vm_qemu.nomad_client_04.cores
      memory    = proxmox_vm_qemu.nomad_client_04.memory
      disk_size = proxmox_vm_qemu.nomad_client_04.disks.0.scsi.scsi0.disk.0.size
    }
  }
}

# -------------------------------------------------------------------------------
# Ansible Inventory
# -------------------------------------------------------------------------------

output "ansible_inventory" {
  description = "Ansible inventory in INI format"
  value = <<-EOT
[nomad_servers]
${join("\n", [for vm in proxmox_vm_qemu.nomad_servers : "${vm.name} ansible_host=${split("/", vm.ipconfig0)[0]}"])}

[nomad_clients_x86]
nomad-client-01 ansible_host=${split("/", proxmox_vm_qemu.nomad_client_01.ipconfig0)[0]}
nomad-client-02 ansible_host=${split("/", proxmox_vm_qemu.nomad_client_02.ipconfig0)[0]}
nomad-client-03 ansible_host=${split("/", proxmox_vm_qemu.nomad_client_03.ipconfig0)[0]}
nomad-client-04 ansible_host=${split("/", proxmox_vm_qemu.nomad_client_04.ipconfig0)[0]}

[nomad_clients:children]
nomad_clients_x86

[nomad_cluster:children]
nomad_servers
nomad_clients
EOT
}
