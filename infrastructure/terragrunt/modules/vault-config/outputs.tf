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
#   - Database Roles: Names of created database roles
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
  value = merge(
    { for k, v in vault_policy.policy : k => v.name },
    length(var.workload_secrets) > 0 && var.policies_enabled ? {
      nomad_workloads = vault_policy.nomad_workloads[0].name
    } : {}
  )
}

# -------------------------------------------------------------------------
# PKI ROLES
# -------------------------------------------------------------------------

output "pki_role_names" {
  description = "Map of created PKI role names"
  value       = { for k, v in vault_pki_secret_backend_role.role : k => v.name }
}

# -------------------------------------------------------------------------
# DATABASE ROLES
# -------------------------------------------------------------------------

output "database_role_names" {
  description = "Map of created database role names"
  value       = { for k, v in vault_database_secret_backend_role.role : k => v.name }
}

# -------------------------------------------------------------------------
# SSH CA
# -------------------------------------------------------------------------

output "ssh_host_signer_path" {
  description = "Path to SSH host signer secrets engine"
  value       = var.ssh_ca_enabled ? vault_mount.ssh_host_signer[0].path : null
}

output "ssh_client_signer_path" {
  description = "Path to SSH client signer secrets engine"
  value       = var.ssh_ca_enabled ? vault_mount.ssh_client_signer[0].path : null
}
