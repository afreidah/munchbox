# -------------------------------------------------------------------------------
# VAULTWARDEN-SECRETS Module Version Requirements
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "~> 0.12"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
