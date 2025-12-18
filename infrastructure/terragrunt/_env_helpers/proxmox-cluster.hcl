# -----------------------------------------------------------------------------
# PROXMOX CLUSTER ENV HELPER
# -----------------------------------------------------------------------------
#
# Manages on-prem Proxmox VMs for the Nomad/Consul cluster.
# VMs are defined in root.hcl and configured via Ansible post-provision.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terraform/modules/proxmox-cluster"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  vms            = local.root.locals.proxmox_vms
  disk_storage   = local.root.locals.proxmox_defaults.disk_storage
  network_bridge = local.root.locals.proxmox_defaults.network_bridge
  template_name  = try(local.root.locals.proxmox_defaults.template_name, "debian-base")
}
