# -----------------------------------------------------------------------------
# PROXMOX CLUSTER - On-Prem Nomad/Consul/Vault VMs
# -----------------------------------------------------------------------------
#
# Manages the VMs in root.hcl `proxmox_vm_groups.cluster` (matched by this
# directory's name). Post-provisioning configuration is handled by Ansible.
#
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "proxmox_cluster" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/proxmox-cluster.hcl"
}
