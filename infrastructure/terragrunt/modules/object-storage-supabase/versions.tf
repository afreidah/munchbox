# -----------------------------------------------------------------------------
# OBJECT-STORAGE-SUPABASE Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    supabase = {
      source  = "shellscape/supabase"
      version = "~> 0.1"
    }
    # --- declared for the vault_kv_secret_v2 data source the env_helper generates into the leaf ---
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0"
    }
  }
}
