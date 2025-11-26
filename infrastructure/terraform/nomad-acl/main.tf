# -------------------------------------------------------------------------------
# Nomad ACL Configuration
#
# Project: Munchbox / Author: Alex Freidah
#
# Terraform configuration for Nomad ACL policies and tokens. Creates operator
# and service-specific policies, generates tokens, and stores them in Vault.
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Providers
# -----------------------------------------------------------------------------

provider "nomad" {
  address     = var.nomad_address
  secret_id   = var.nomad_token
  skip_verify = true
}

provider "vault" {
  address         = var.vault_address
  token           = var.vault_token
  skip_tls_verify = true
}
