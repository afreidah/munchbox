# -------------------------------------------------------------------------------
# CONSUL-ACLS Module Version Requirements
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.20"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
