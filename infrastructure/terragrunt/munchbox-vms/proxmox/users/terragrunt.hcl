# -----------------------------------------------------------------------------
# PROXMOX USERS - Service Accounts & ACLs
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "proxmox_users" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/proxmox-users.hcl"
}
