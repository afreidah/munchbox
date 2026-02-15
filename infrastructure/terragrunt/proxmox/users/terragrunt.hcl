# -----------------------------------------------------------------------------
# PROXMOX USERS - Service Accounts & ACLs
# -----------------------------------------------------------------------------
#
# Manages Proxmox users for service accounts (monitoring, backups, etc).
# Uses bpg/proxmox provider for user management capabilities.
#
# Note: Does NOT include root.hcl to avoid provider generation conflicts.
# This config is standalone with its own provider and backend config.
#
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/modules/proxmox-users"
}

locals {
  root = read_terragrunt_config("${get_repo_root()}/infrastructure/terragrunt/root.hcl")

  # Convert telmate-style env vars to bpg format
  pm_api_url          = get_env("PM_API_URL", "")
  pm_api_token_id     = get_env("PM_API_TOKEN_ID", "")
  pm_api_token_secret = get_env("PM_API_TOKEN_SECRET", "")

  # bpg provider wants endpoint without /api2/json suffix
  proxmox_endpoint = replace(local.pm_api_url, "/api2/json", "")
  proxmox_token    = "${local.pm_api_token_id}=${local.pm_api_token_secret}"
}

# Remote state in Consul
remote_state {
  backend = "consul"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    address = "consul.service.consul:8500"
    scheme  = "http"
    path    = "terraform/munchbox/proxmox/users"
    lock    = true
  }
}

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.0"

      required_providers {
        proxmox = {
          source  = "bpg/proxmox"
          version = "~> 0.95"
        }
        vault = {
          source  = "hashicorp/vault"
          version = "~> 3.25"
        }
      }
    }

    provider "proxmox" {
      endpoint  = "${local.proxmox_endpoint}"
      api_token = "${local.proxmox_token}"
      insecure  = true
    }

    provider "vault" {
      # Uses VAULT_ADDR and VAULT_TOKEN env vars
    }
  EOF
}

inputs = {
  roles = local.root.locals.proxmox_roles
  users = local.root.locals.proxmox_users
}
