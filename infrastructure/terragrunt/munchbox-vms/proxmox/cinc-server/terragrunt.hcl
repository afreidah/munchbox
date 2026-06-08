# -----------------------------------------------------------------------------
# PROXMOX CINC-SERVER - Dedicated VM for cinc/chef server
# -----------------------------------------------------------------------------
#
# Manages the VM in root.hcl `proxmox_vm_groups.cinc-server` (matched by this
# directory's name). Hosts the cinc-server that will drive the chef migration
# from ansible (see #81).
#
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "proxmox_cluster" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/proxmox-cluster.hcl"
}
