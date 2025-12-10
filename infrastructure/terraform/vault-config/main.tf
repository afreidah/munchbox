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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "consul" {
    address = "stabler:8500"
    scheme  = "http"
    path    = "terraform/vault-config"
  }
}

provider "vault" {
  address  = "https://192.168.68.61:8200"
  ca_cert_file = pathexpand("~/.munchbox/ca-chain.crt")
}

# -------------------------------------------------------------------------------
# Data Sources
# -------------------------------------------------------------------------------

data "vault_generic_secret" "pki_int_ca" {
  path = "pki_int/cert/ca"
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

# -------------------------------------------------------------------------------
# JWT Auth Backend for Nomad Workload Identity
# -------------------------------------------------------------------------------

resource "vault_jwt_auth_backend" "nomad" {
  path               = "jwt-nomad"
  type               = "jwt"
  description        = "JWT auth for Nomad workload identity"
  jwks_url           = "https://stabler:4646/.well-known/jwks.json"
  jwt_supported_algs = ["RS256", "EdDSA"]
  default_role       = "nomad-workloads"
  jwks_ca_pem        = data.vault_generic_secret.pki_int_ca.data["certificate"]
}

resource "vault_jwt_auth_backend_role" "nomad_workloads" {
  backend                 = vault_jwt_auth_backend.nomad.path
  role_name               = "nomad-workloads"
  role_type               = "jwt"
  bound_audiences         = ["vault.io"]
  user_claim              = "/nomad_job_id"
  user_claim_json_pointer = true

  claim_mappings = {
    "nomad_namespace" = "nomad_namespace"
    "nomad_job_id"    = "nomad_job_id"
    "nomad_task"      = "nomad_task"
  }

  token_type     = "service"
  token_ttl      = 3600
  token_max_ttl  = 86400
  token_policies = ["nomad-workloads"]
}
