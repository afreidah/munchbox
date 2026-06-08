# -----------------------------------------------------------------------------
# OBJECT-STORAGE-MINIO Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "~> 3.0"
    }
    # --- declared for the vault_kv_secret_v2 data source the env_helper generates into the leaf ---
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0"
    }
  }
}
