# -----------------------------------------------------------------------------
# PASSWORDS ENV HELPER
# -----------------------------------------------------------------------------
#
# Generates the passwords below. Vault-free: the values are exposed as outputs
# and written to Vault by the vault-secrets leaf via terragrunt dependency.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//passwords"
}

locals {
  # --- key = Vault secret name, inner keys = its data keys. These two are the
  #     credentials terraform authenticates to Proxmox and Vaultwarden with, so
  #     they carry the value each system already issued and the lengths describe
  #     it rather than drive it. They live at their own paths because
  #     vault-kv-secrets owns the whole key map at a path, and secret/proxmox
  #     and secret/vaultwarden hold unrelated fields. ---
  password_requests = {
    "proxmox/api-token" = {
      id     = { length = 24 }
      secret = { length = 36 }
    }
    "vaultwarden/master-password" = {
      password = { length = 15 }
    }
  }
}

inputs = {
  passwords = local.password_requests
}
