# -----------------------------------------------------------------------------
# PROXMOX CLUSTER ENV HELPER
# -----------------------------------------------------------------------------
#
# Manages a group of on-prem Proxmox VMs. The calling terragrunt directory's
# name (e.g. `cluster`, `cinc-server`) selects which group from
# `proxmox_vm_groups` in root.hcl gets provisioned, so a new VM group is
# added by dropping a new directory under terragrunt/proxmox/ and adding
# the matching key to root.hcl.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/modules/proxmox-cluster"
}

locals {
  root       = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  group_name = basename(get_terragrunt_dir())
  group      = local.root.locals.proxmox_vm_groups[local.group_name]
}

inputs = {
  vms            = local.group
  disk_storage   = local.root.locals.proxmox_defaults.disk_storage
  network_bridge = local.root.locals.proxmox_defaults.network_bridge
  template_name  = try(local.root.locals.proxmox_defaults.template_name, "debian-base")
}
