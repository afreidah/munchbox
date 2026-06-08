# -------------------------------------------------------------------------------
# OBJECT-STORAGE-B2 Module Version Requirements
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    b2 = {
      source  = "Backblaze/b2"
      version = "~> 0.10"
    }
    # --- declared for the vault_kv_secret_v2 data source the env_helper generates into the leaf ---
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0"
    }
  }
}
