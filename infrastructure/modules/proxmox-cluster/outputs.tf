# -----------------------------------------------------------------------------
# PROXMOX CLUSTER MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "vms" {
  description = "Map of VM details"
  value = {
    for name, vm in proxmox_vm_qemu.vm : name => {
      vmid        = vm.vmid
      target_node = vm.target_node
      name        = vm.name
      memory      = vm.memory
      cores       = vm.cpu[0].cores
    }
  }
}

output "vm_names" {
  description = "List of VM names"
  value       = [for name, vm in proxmox_vm_qemu.vm : vm.name]
}
