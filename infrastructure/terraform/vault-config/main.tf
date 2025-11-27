# -------------------------------------------------------------------------------
# Vault Configuration - Secrets Engines
#
# Project: Munchbox / Author: Alex Freidah
#
# Enables and configures Vault secrets engines for Munchbox infrastructure.
# Run this FIRST before consul-acls module.
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.25"
    }
  }

  backend "consul" {
    address = "stabler:8500"
    scheme  = "http"
    path    = "terraform/vault-config"
  }
}

provider "vault" {
  address         = "http://192.168.68.61:8200"
  skip_tls_verify = true
}

# -------------------------------------------------------------------------------
# KV v2 Secrets Engine
# -------------------------------------------------------------------------------

resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv"
  description = "KV v2 secrets engine for Munchbox"

  options = {
    version = "2"
  }
}

# -------------------------------------------------------------------------------
# Consul Secrets Engine (Dynamic Tokens)
# -------------------------------------------------------------------------------

resource "vault_consul_secret_backend" "consul" {
  path        = "consul"
  description = "Consul secrets engine for dynamic token generation"
  address     = "http://192.168.68.61:8500"
  scheme      = "http"
  token       = var.consul_bootstrap_token
}
