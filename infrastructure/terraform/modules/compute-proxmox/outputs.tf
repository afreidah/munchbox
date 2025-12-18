# -----------------------------------------------------------------------------
# COMPUTE MODULE (PROXMOX) - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "id" {
  description = "VM ID"
  value       = proxmox_vm_qemu.this.vmid
}

output "name" {
  description = "VM name"
  value       = proxmox_vm_qemu.this.name
}

output "target_node" {
  description = "Proxmox node hosting the VM"
  value       = proxmox_vm_qemu.this.target_node
}

# Note: Proxmox doesn't directly expose IPs like cloud providers
# IPs come from local network (DHCP/static) and require guest agent
output "default_ipv4_address" {
  description = "Primary IPv4 address (requires QEMU guest agent)"
  value       = proxmox_vm_qemu.this.default_ipv4_address
}

output "ssh_connection_string" {
  description = "SSH connection command (uses default IP)"
  value       = proxmox_vm_qemu.this.default_ipv4_address != "" ? "ssh root@${proxmox_vm_qemu.this.default_ipv4_address}" : "ssh root@${var.name}"
}

output "cores" {
  description = "Number of CPU cores"
  value       = var.cores
}

output "memory_mb" {
  description = "Memory in MB"
  value       = var.memory_mb
}

output "disk_size" {
  description = "Disk size"
  value       = var.disk_size
}
