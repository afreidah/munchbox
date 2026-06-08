# -----------------------------------------------------------------------------
# OBJECT-STORAGE-S3COMPAT Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # --- declared for the vault_kv_secret_v2 data source the env_helper generates into the leaf ---
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0"
    }
  }
}
