# -----------------------------------------------------------------------------
# PROXMOX NOMAD-SERVER-03 - Single cluster VM leaf
# -----------------------------------------------------------------------------
#
# Manages the single VM in root.hcl `proxmox_vm_groups.nomad-server-03`
# (matched by this directory's name) so it can be planned/applied on its own.
#
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "proxmox_cluster" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/proxmox-cluster.hcl"
}
