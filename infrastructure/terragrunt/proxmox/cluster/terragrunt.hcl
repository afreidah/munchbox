# -----------------------------------------------------------------------------
# PROXMOX CLUSTER - On-Prem VMs
# -----------------------------------------------------------------------------
#
# Manages all Proxmox VMs defined in root.hcl proxmox_vms.
# Post-provisioning configuration is handled by Ansible.
#
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "proxmox_cluster" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/proxmox-cluster.hcl"
}
