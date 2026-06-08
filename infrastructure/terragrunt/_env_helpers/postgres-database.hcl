# -----------------------------------------------------------------------------
# POSTGRES-DATABASE ENV HELPER  (one leaf per app under postgres/<app>)
# -----------------------------------------------------------------------------
#
# Leaf dir name is the app key: it looks up root.hcl's postgres_databases[<app>]
# for the vault path + database list, and the module owns the login role + its
# databases. Replaces the Patroni post-init.sh SQL with idempotent, apply-time
# provisioning. The postgresql provider connects to the Patroni primary directly
# as the shared superuser (creds from Vault secret/postgres-shared/root).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  app  = basename(get_terragrunt_dir())
  cfg  = local.root.locals.postgres_databases[local.app]
}

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//postgres-database"
}

# --- postgresql provider: superuser from Vault, direct to the Patroni primary for DDL ---
generate "provider_postgresql" {
  path      = "provider_postgresql.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    data "vault_kv_secret_v2" "pg_root" {
      mount = "secret"
      name  = "postgres-shared/root"
    }

    provider "postgresql" {
      host            = "postgres-primary.service.consul"
      port            = 5432
      database        = "postgres"
      username        = data.vault_kv_secret_v2.pg_root.data["username"]
      password        = data.vault_kv_secret_v2.pg_root.data["password"]
      sslmode         = "require"
      connect_timeout = 15
    }
  EOF
}

inputs = {
  app            = local.app
  vault_kv_path  = local.cfg.vault_kv_path
  username_field = lookup(local.cfg, "username_field", "db_username")
  password_field = lookup(local.cfg, "password_field", "db_password")
  databases      = local.cfg.databases
  manage_secret  = lookup(local.cfg, "manage_secret", false)
  extensions     = lookup(local.cfg, "extensions", {})
}
