# -------------------------------------------------------------------------------
# Vault Database Secrets Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# Two-phase setup:
# 1. Creates static root password in Vault KV (always runs)
# 2. Configures database secrets engine (only if postgres is running)
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Generate Root Password (Phase 1)
# -------------------------------------------------------------------------------

resource "random_password" "postgres_root" {
  length  = 32
  special = true
}

resource "vault_kv_secret_v2" "postgres_root" {
  mount = vault_mount.kv.path
  name  = "postgres-shared/root"

  data_json = jsonencode({
    username = "postgres"
    password = random_password.postgres_root.result
    host     = "postgres-shared.service.consul"
    port     = 5432
  })
}

# -------------------------------------------------------------------------------
# Enable Database Secrets Engine (Phase 3)
# Only runs if var.configure_database_engine = true
# -------------------------------------------------------------------------------

resource "vault_database_secrets_mount" "postgres" {
  count = var.configure_database_engine ? 1 : 0
  path  = "database"

  postgresql {
    name              = "postgres-shared"
    username          = "postgres"
    password          = random_password.postgres_root.result
    connection_url    = "postgresql://{{username}}:{{password}}@postgres-shared.service.consul:5432/postgres?sslmode=disable"
    verify_connection = true
    allowed_roles     = ["temporal", "rreading-glasses"]
  }
}

# -------------------------------------------------------------------------------
# Database Role: Temporal
# -------------------------------------------------------------------------------

resource "vault_database_secret_backend_role" "temporal" {
  count   = var.configure_database_engine ? 1 : 0
  backend = vault_database_secrets_mount.postgres[0].path
  name    = "temporal"
  db_name = vault_database_secrets_mount.postgres[0].postgresql[0].name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT ALL PRIVILEGES ON DATABASE temporal TO \"{{name}}\";",
    "GRANT ALL ON SCHEMA public TO \"{{name}}\";"
  ]

  default_ttl = 86400
  max_ttl     = 259200
}

# -------------------------------------------------------------------------------
# Database Role: rreading-glasses
# -------------------------------------------------------------------------------

resource "vault_database_secret_backend_role" "rreading_glasses" {
  count   = var.configure_database_engine ? 1 : 0
  backend = vault_database_secrets_mount.postgres[0].path
  name    = "rreading-glasses"
  db_name = vault_database_secrets_mount.postgres[0].postgresql[0].name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT ALL PRIVILEGES ON DATABASE rreading_glasses TO \"{{name}}\";",
    "GRANT ALL ON SCHEMA public TO \"{{name}}\";"
  ]

  default_ttl = 86400
  max_ttl     = 259200
}
