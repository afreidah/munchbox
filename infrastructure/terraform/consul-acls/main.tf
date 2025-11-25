# -------------------------------------------------------------------------------
# Consul ACL Configuration
#
# Project: Munchbox / Author: Alex Freidah
#
# Bootstraps Consul ACLs, creates policies and tokens, stores tokens in Vault.
# Run after bootstrapping ACLs with bootstrap-acls.sh script.
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.20"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.25"
    }
  }
  
  # Backend will be added after ACLs are working
}

# -------------------------------------------------------------------------------
# Provider Configuration
# -------------------------------------------------------------------------------

provider "consul" {
  address = "http://stabler:8500"
  # Set via environment: CONSUL_HTTP_TOKEN, CONSUL_CACERT
}

provider "vault" {
  address         = "http://192.168.68.61:8200"
  skip_tls_verify = false
  # Set via environment: VAULT_TOKEN
}

# -------------------------------------------------------------------------------
# Consul ACL Policies
# -------------------------------------------------------------------------------

resource "consul_acl_policy" "nomad_server" {
  name  = "nomad-server"
  rules = file("${path.module}/policies/nomad-server.hcl")
}

resource "consul_acl_policy" "nomad_client" {
  name  = "nomad-client"
  rules = file("${path.module}/policies/nomad-client.hcl")
}

resource "consul_acl_policy" "vault_storage" {
  name  = "vault-storage"
  rules = file("${path.module}/policies/vault-storage.hcl")
}

# -------------------------------------------------------------------------------
# Consul ACL Tokens
# -------------------------------------------------------------------------------

resource "consul_acl_token" "nomad_server" {
  description = "Token for Nomad servers"
  policies    = [consul_acl_policy.nomad_server.name]
  local       = false
}

resource "consul_acl_token" "nomad_client" {
  description = "Token for Nomad clients"
  policies    = [consul_acl_policy.nomad_client.name]
  local       = false
}

resource "consul_acl_token" "vault_storage" {
  description = "Token for Vault storage backend"
  policies    = [consul_acl_policy.vault_storage.name]
  local       = false
}

# -------------------------------------------------------------------------------
# Store Tokens in Vault KV
# -------------------------------------------------------------------------------

resource "vault_kv_secret_v2" "consul_bootstrap" {
  mount = "secret"
  name  = "consul/bootstrap-token"
  
  data_json = jsonencode({
    token       = var.consul_bootstrap_token
    description = "Consul ACL bootstrap token - CRITICAL"
  })
}

resource "vault_kv_secret_v2" "nomad_server_token" {
  mount = "secret"
  name  = "consul/nomad-server-token"
  
  data_json = jsonencode({
    token       = consul_acl_token.nomad_server.id
    accessor_id = consul_acl_token.nomad_server.accessor_id
  })
}

resource "vault_kv_secret_v2" "nomad_client_token" {
  mount = "secret"
  name  = "consul/nomad-client-token"
  
  data_json = jsonencode({
    token       = consul_acl_token.nomad_client.id
    accessor_id = consul_acl_token.nomad_client.accessor_id
  })
}

resource "vault_kv_secret_v2" "vault_storage_token" {
  mount = "secret"
  name  = "consul/vault-storage-token"
  
  data_json = jsonencode({
    token       = consul_acl_token.vault_storage.id
    accessor_id = consul_acl_token.vault_storage.accessor_id
  })
}

# Health checks policy for anonymous token
resource "consul_acl_policy" "health_checks" {
  name  = "health-checks"
  rules = file("${path.module}/policies/health-checks.hcl")
}
