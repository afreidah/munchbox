# -------------------------------------------------------------------------------
# Proxmox VM Module — Basic Provisioning Test
#
# Project: Munchbox / Author: Alex Freidah
#
# Validates core provisioning logic for the Proxmox VM module. Ensures that
# input variables are correctly mapped to resource attributes and that the
# module produces expected state for Nomad server and client VMs.
# -------------------------------------------------------------------------------

variables {
  proxmox_api_url          = "https://192.168.68.65:8006/api2/json"
  proxmox_api_token_id     = "testuser@pve!testtoken"
  proxmox_api_token_secret = "supersecret"
  proxmox_tls_insecure     = true
  template_name            = "debian-base"
  vm_disk_storage          = "local-lvm"
  vm_network_bridge        = "vmbr0"
  vms = {
    "nomad-server-01" = {
      target_node     = "stabler"
      vmid            = 101
      memory          = 2048
      cores           = 2
      disk_size       = "32G"
      gpu_passthrough = false
    }
    "nomad-client-01" = {
      target_node     = "goren"
      vmid            = 102
      memory          = 2048
      cores           = 2
      disk_size       = "32G"
      gpu_passthrough = false
    }
  }
}

# --- Basic provisioning assertions ---
run "basic_vm_plan" {
  command = plan
  variables {
    # use test defaults
  }
  assert {
    condition     = proxmox_vm_qemu.nomad_server.memory == var.vms["nomad-server-01"].memory
    error_message = "Nomad server VM memory should match input variable"
  }
  assert {
    condition     = proxmox_vm_qemu.nomad_client_01.memory == var.vms["nomad-client-01"].memory
    error_message = "Nomad client VM memory should match input variable"
  }
  assert {
    condition     = proxmox_vm_qemu.nomad_server.target_node == var.vms["nomad-server-01"].target_node
    error_message = "Nomad server VM should be assigned to the correct node"
  }
}
