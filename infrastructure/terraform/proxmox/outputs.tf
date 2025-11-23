# -------------------------------------------------------------------------------
# Proxmox VM Provisioning - Outputs
#
# Project: Munchbox / Author: Alex Freidah
#
# Exposes VM metadata for downstream automation. IP assignment is managed
# externally (DHCP or static configuration). Two additional Nomad servers
# (stabler, goren) run bare metal on Raspberry Pi5s.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Nomad Server
# -------------------------------------------------------------------------------

output "nomad_server" {
  description = "Nomad server VM metadata"
  value = {
    vmid   = proxmox_vm_qemu.nomad_server.vmid
    node   = proxmox_vm_qemu.nomad_server.target_node
    memory = proxmox_vm_qemu.nomad_server.memory
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
  }
}

# -------------------------------------------------------------------------------
# Ansible Inventory
# -------------------------------------------------------------------------------

output "ansible_inventory" {
  description = "Ansible inventory in INI format"
  value       = <<-EOT
# -------------------------------------------------------------------------------
# Dynamic Inventory - Nomad Cluster
#
# Project: Munchbox / Author: Alex Freidah
#
# Mixed infrastructure: Nomad servers on bare-metal Pi5s (stabler, goren) and
# one VM server on fontana. Clients run as VMs distributed across Proxmox hosts.
# IP addresses assigned via DHCP or static configuration.
# -------------------------------------------------------------------------------

[nomad_servers]
stabler ansible_host=192.168.68.66 ansible_connection=ssh
goren ansible_host=192.168.68.67 ansible_connection=ssh
nomad-server-03 ansible_host=192.168.68.72

[nomad_clients]
nomad-client-01 ansible_host=192.168.68.80
nomad-client-02 ansible_host=192.168.68.81
nomad-client-03 ansible_host=192.168.68.82

[nomad_servers_arm64]
stabler
goren

[nomad_servers_x86_64]
nomad-server-03

[nomad_cluster:children]
nomad_servers
nomad_clients

[nomad_cluster:vars]
ansible_user=ansible
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_python_interpreter=/usr/bin/python3

[nomad_servers_arm64:vars]
nomad_arch=arm64

[nomad_servers_x86_64:vars]
nomad_arch=amd64
EOT
}
