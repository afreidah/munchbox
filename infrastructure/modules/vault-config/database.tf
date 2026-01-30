# -------------------------------------------------------------------------------
# Vault Database Secrets Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages PostgreSQL credentials in two phases:
#   - Phase 1: Stores static root password in Vault KV (always when kv_enabled)
#   - Phase 2: Configures dynamic credentials (when database_secrets_enabled)
#
# Database roles are defined via the database_roles input variable from root.hcl.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# POSTGRES ROOT PASSWORD
# -------------------------------------------------------------------------

resource "random_password" "postgres_root" {
  count   = var.kv_enabled ? 1 : 0
  length  = 32
  special = true
}

resource "vault_kv_secret_v2" "postgres_root" {
  count = var.kv_enabled ? 1 : 0
  mount = vault_mount.kv[0].path
  name  = "postgres-shared/root"

  data_json = jsonencode({
    username = "postgres"
    password = random_password.postgres_root[0].result
    host     = var.postgres_host
    port     = var.postgres_port
  })
}

# -------------------------------------------------------------------------
# DATABASE SECRETS ENGINE
# -------------------------------------------------------------------------

resource "vault_database_secrets_mount" "postgres" {
  count = var.database_secrets_enabled ? 1 : 0
  path  = "database"

  postgresql {
    name              = "postgres-shared"
    username          = "postgres"
    password          = random_password.postgres_root[0].result
    connection_url    = "postgresql://{{username}}:{{password}}@${var.postgres_host}:${var.postgres_port}/postgres?sslmode=disable"
    verify_connection = true
    allowed_roles     = keys(var.database_roles)
  }
}

# -------------------------------------------------------------------------
# DATABASE ROLES
# -------------------------------------------------------------------------

resource "vault_database_secret_backend_role" "role" {
  for_each = var.database_secrets_enabled ? var.database_roles : {}

  backend = vault_database_secrets_mount.postgres[0].path
  name    = each.key
  db_name = vault_database_secrets_mount.postgres[0].postgresql[0].name

  creation_statements = each.value.creation_statements
  default_ttl         = each.value.default_ttl
  max_ttl             = each.value.max_ttl
}
