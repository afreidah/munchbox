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
    address = "stabler:8501"
    scheme  = "https"
    path    = "terraform/vault-config"
    ca_file = "/etc/consul.d/tls/ca-chain.crt"
  }
}

provider "vault" {
  address          = "http://192.168.68.61:8200"
  skip_tls_verify  = true
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
  
  address = "https://192.168.68.61:8501"
  scheme  = "https"
  token   = var.consul_bootstrap_token
  
  ca_cert = file("/etc/consul.d/tls/ca-chain.crt")
}

# -------------------------------------------------------------------------------
# Vault Policies
# -------------------------------------------------------------------------------

resource "vault_policy" "consul_token_read" {
  name = "consul-token-read"
  
  policy = <<EOT
# Read Consul tokens from KV
path "secret/data/consul/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "nomad_server" {
  name = "nomad-server"
  
  policy = <<EOT
# Nomad servers need to read Consul tokens
path "secret/data/consul/nomad-server-token" {
  capabilities = ["read"]
}

# Issue certificates from PKI
path "pki_int/issue/nomad-server" {
  capabilities = ["create", "update"]
}
EOT
}

resource "vault_policy" "nomad_client" {
  name = "nomad-client"
  
  policy = <<EOT
# Nomad clients need to read Consul tokens
path "secret/data/consul/nomad-client-token" {
  capabilities = ["read"]
}

# Issue certificates from PKI
path "pki_int/issue/nomad-client" {
  capabilities = ["create", "update"]
}
EOT
}
