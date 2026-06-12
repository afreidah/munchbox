# -----------------------------------------------------------------------------
# PROXMOX-USERS ENV HELPER
# -----------------------------------------------------------------------------
#
# Manages Proxmox users/roles/ACLs via bpg/proxmox. The module's versions.tf
# pins bpg as the proxmox source; this env_helper overrides root.hcl's
# providers.tf with bpg-shaped config (root writes first, this overwrites).
#
# Roles/users/ACLs are defined here. Env vars: PM_API_URL, PM_API_TOKEN_ID,
# PM_API_TOKEN_SECRET.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//proxmox-users"
}

locals {
  proxmox_roles = {
    "prometheus-exporter" = {
      privileges = [
        "Sys.Audit",
        "SDN.Audit",
        "Datastore.Audit",
        "Pool.Audit",
        "VM.Audit",
      ]
    }
  }

  proxmox_users = {
    "prometheus" = {
      user_id = "prometheus@pve"
      comment = "PVE Exporter service account"
      # Password managed manually (API tokens can't change passwords)
      # Password stored in Vault at secret/proxmox for pve-exporter
      acls = [
        {
          path    = "/"
          role_id = "prometheus-exporter"
        }
      ]
    }
  }

  # --- bpg wants endpoint WITHOUT /api2/json suffix + a combined api_token string ---
  pm_api_url          = get_env("PM_API_URL", "")
  pm_api_token_id     = get_env("PM_API_TOKEN_ID", "")
  pm_api_token_secret = get_env("PM_API_TOKEN_SECRET", "")
  proxmox_endpoint    = replace(local.pm_api_url, "/api2/json", "")
  proxmox_token       = "${local.pm_api_token_id}=${local.pm_api_token_secret}"
}

# --- overrides the providers.tf root.hcl wrote (telmate-flavored) with bpg-shape ---
generate "providers_proxmox_users" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "proxmox" {
      endpoint  = "${local.proxmox_endpoint}"
      api_token = "${local.proxmox_token}"
      insecure  = true
    }

    provider "vault" {
      # Uses VAULT_ADDR + VAULT_TOKEN env vars
    }
  EOF
}

inputs = {
  roles = local.proxmox_roles
  users = local.proxmox_users
}
