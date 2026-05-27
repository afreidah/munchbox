# -------------------------------------------------------------------------------
# PROXMOX-USERS Module Version Requirements
# -------------------------------------------------------------------------------
# Uses bpg/proxmox — telmate/proxmox doesn't expose user/role/ACL resources.
# The proxmox-users env_helper overwrites root.hcl's providers.tf with a
# bpg-shaped provider config.
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.95"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
