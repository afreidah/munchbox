# -------------------------------------------------------------------------------
# Vault Database Secrets Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages PostgreSQL credentials in two phases:
#   - Phase 1: Stores static root password in Vault KV (always when kv_enabled)
#   - Phase 2: Configures dynamic credentials (when database_secrets_enabled)
#
# Database roles are created for each application requiring PostgreSQL access.
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
    allowed_roles     = var.database_roles
  }
}

# -------------------------------------------------------------------------
# DATABASE ROLE: TEMPORAL
# -------------------------------------------------------------------------

resource "vault_database_secret_backend_role" "temporal" {
  count   = var.database_secrets_enabled && contains(var.database_roles, "temporal") ? 1 : 0
  backend = vault_database_secrets_mount.postgres[0].path
  name    = "temporal"
  db_name = vault_database_secrets_mount.postgres[0].postgresql[0].name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT ALL PRIVILEGES ON DATABASE temporal TO \"{{name}}\";",
    "GRANT ALL ON SCHEMA public TO \"{{name}}\";"
  ]

  default_ttl = var.database_default_ttl
  max_ttl     = var.database_max_ttl
}

# -------------------------------------------------------------------------
# DATABASE ROLE: KANBOARD
# -------------------------------------------------------------------------

resource "vault_database_secret_backend_role" "kanboard" {
  count   = var.database_secrets_enabled && contains(var.database_roles, "kanboard") ? 1 : 0
  backend = vault_database_secrets_mount.postgres[0].path
  name    = "kanboard"
  db_name = vault_database_secrets_mount.postgres[0].postgresql[0].name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT CONNECT ON DATABASE kanboard TO \"{{name}}\";",
    "GRANT USAGE, CREATE ON SCHEMA public TO \"{{name}}\";",
    "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
    "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";",
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"{{name}}\";",
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"{{name}}\";"
  ]

  default_ttl = var.database_default_ttl
  max_ttl     = var.database_max_ttl
}
