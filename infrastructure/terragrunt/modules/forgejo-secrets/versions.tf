# -------------------------------------------------------------------------------
# FORGEJO-SECRETS Module Version Requirements
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    forgejo = {
      source  = "svalabs/forgejo"
      version = "~> 1.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
