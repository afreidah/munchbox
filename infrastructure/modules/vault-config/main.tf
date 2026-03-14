# -------------------------------------------------------------------------------
# VAULT-CONFIG MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Configures HashiCorp Vault secrets engines, auth backends, and policies for
# Munchbox infrastructure. Components can be enabled/disabled via feature flags.
#
# Components:
#   - KV v2 Secrets Engine: General-purpose secret storage
#   - Consul Secrets Engine: Dynamic Consul token generation
#   - JWT Auth Backend: Nomad workload identity authentication
#   - Database Secrets Engine: Dynamic PostgreSQL credentials
#   - PKI Roles: Certificate issuance for Traefik and PostgreSQL
#   - Policies: Access control for infrastructure components
#
# IMPORTANT:
#   - KV engine must be enabled before other components that store secrets
#   - Consul secrets engine requires a bootstrap token with ACL management
#   - Database engine requires PostgreSQL to be running and accessible
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# DATA SOURCES
# -------------------------------------------------------------------------

data "vault_generic_secret" "pki_int_ca" {
  count = var.jwt_auth_enabled ? 1 : 0
  path  = "pki_int/cert/ca"
}

# -------------------------------------------------------------------------
# KV V2 SECRETS ENGINE
# -------------------------------------------------------------------------

resource "vault_mount" "kv" {
  count       = var.kv_enabled ? 1 : 0
  path        = var.kv_path
  type        = "kv"
  description = "KV v2 secrets engine for Munchbox"

  options = {
    version = "2"
  }
}

# -------------------------------------------------------------------------
# CONSUL SECRETS ENGINE
# -------------------------------------------------------------------------

resource "vault_consul_secret_backend" "consul" {
  count       = var.consul_secrets_enabled ? 1 : 0
  path        = "consul"
  description = "Consul secrets engine for dynamic token generation"
  address     = var.consul_address
  scheme      = var.consul_scheme
  token       = var.consul_bootstrap_token
}

# -------------------------------------------------------------------------
# JWT AUTH BACKEND FOR NOMAD WORKLOAD IDENTITY
# -------------------------------------------------------------------------

resource "vault_jwt_auth_backend" "nomad" {
  count              = var.jwt_auth_enabled ? 1 : 0
  path               = "jwt-nomad"
  type               = "jwt"
  description        = "JWT auth for Nomad workload identity"
  jwks_url           = var.nomad_jwks_url
  jwt_supported_algs = ["RS256", "EdDSA"]
  default_role       = "nomad-workloads"
  jwks_ca_pem        = data.vault_generic_secret.pki_int_ca[0].data["certificate"]
}

resource "vault_jwt_auth_backend_role" "nomad_workloads" {
  count                   = var.jwt_auth_enabled ? 1 : 0
  backend                 = vault_jwt_auth_backend.nomad[0].path
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

# -------------------------------------------------------------------------
# WORKLOAD-SPECIFIC JWT ROLES
# -------------------------------------------------------------------------
# Per-job JWT roles with bound_claims so only the named Nomad job receives
# the additional policies (e.g. Transit encrypt/decrypt).

resource "vault_jwt_auth_backend_role" "workload" {
  for_each = var.jwt_auth_enabled ? var.workload_vault_roles : {}

  backend                 = vault_jwt_auth_backend.nomad[0].path
  role_name               = each.key
  role_type               = "jwt"
  bound_audiences         = ["vault.io"]
  user_claim              = "/nomad_job_id"
  user_claim_json_pointer = true
  bound_claims            = each.value.bound_claims

  claim_mappings = {
    "nomad_namespace" = "nomad_namespace"
    "nomad_job_id"    = "nomad_job_id"
    "nomad_task"      = "nomad_task"
  }

  token_type     = "service"
  token_ttl      = each.value.token_ttl
  token_max_ttl  = each.value.token_max_ttl
  token_policies = each.value.policies
}
