# -----------------------------------------------------------------------------
# PROXMOX-USERS ENV HELPER
# -----------------------------------------------------------------------------
#
# Manages Proxmox users/roles/ACLs via bpg/proxmox. The module's versions.tf
# pins bpg as the proxmox source; this env_helper overrides root.hcl's
# providers.tf with bpg-shaped config (root writes first, this overwrites).
#
# Inputs are pulled from root.hcl locals (proxmox_roles / proxmox_users).
# Env vars: PM_API_URL, PM_API_TOKEN_ID, PM_API_TOKEN_SECRET.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//proxmox-users"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

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
  roles = local.root.locals.proxmox_roles
  users = local.root.locals.proxmox_users
}
