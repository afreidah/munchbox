# -------------------------------------------------------------------------------
# VAULT-CONFIG Module Version Requirements
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
