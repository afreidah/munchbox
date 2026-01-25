# -------------------------------------------------------------------------------
# VAULT-CONFIG MODULE - OUTPUT VALUES
#
# Project: Munchbox / Author: Alex Freidah
#
# Output Categories:
#   - Mount Paths: Paths to enabled secrets engines
#   - Auth Backends: Authentication backend paths
#   - Policy Names: Names of created policies
#   - PKI Roles: Names of created PKI roles
#
# Usage:
#   - kv_path: For storing secrets in KV v2 engine
#   - consul_backend_path: For generating dynamic Consul tokens
#   - jwt_auth_path: For Nomad workload identity auth
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# MOUNT PATHS
# -------------------------------------------------------------------------

output "kv_path" {
  description = "Path to KV v2 secrets engine"
  value       = var.kv_enabled ? vault_mount.kv[0].path : null
}

output "consul_backend_path" {
  description = "Path to Consul secrets engine"
  value       = var.consul_secrets_enabled ? vault_consul_secret_backend.consul[0].path : null
}

output "database_backend_path" {
  description = "Path to database secrets engine"
  value       = var.database_secrets_enabled ? vault_database_secrets_mount.postgres[0].path : null
}

# -------------------------------------------------------------------------
# AUTH BACKENDS
# -------------------------------------------------------------------------

output "jwt_auth_path" {
  description = "Path to JWT auth backend for Nomad workload identity"
  value       = var.jwt_auth_enabled ? vault_jwt_auth_backend.nomad[0].path : null
}

# -------------------------------------------------------------------------
# POLICY NAMES
# -------------------------------------------------------------------------

output "policy_names" {
  description = "Map of created policy names"
  value = var.policies_enabled ? {
    consul_token_read  = vault_policy.consul_token_read[0].name
    nomad_server       = vault_policy.nomad_server[0].name
    nomad_client       = vault_policy.nomad_client[0].name
    nomad_workloads    = vault_policy.nomad_workloads[0].name
    vault_cert_manager = vault_policy.vault_cert_manager[0].name
    backup_worker      = vault_policy.backup_worker[0].name
  } : {}
}

# -------------------------------------------------------------------------
# PKI ROLES
# -------------------------------------------------------------------------

output "pki_role_names" {
  description = "Map of created PKI role names"
  value = var.pki_roles_enabled ? {
    traefik  = vault_pki_secret_backend_role.traefik[0].name
    postgres = vault_pki_secret_backend_role.postgres[0].name
  } : {}
}

# -------------------------------------------------------------------------
# DATABASE ROLES
# -------------------------------------------------------------------------

output "database_role_names" {
  description = "List of created database role names"
  value = var.database_secrets_enabled ? compact([
    contains(var.database_roles, "temporal") ? vault_database_secret_backend_role.temporal[0].name : null,
    contains(var.database_roles, "kanboard") ? vault_database_secret_backend_role.kanboard[0].name : null
  ]) : []
}
