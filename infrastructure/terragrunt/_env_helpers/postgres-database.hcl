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
  app = basename(get_terragrunt_dir())
  cfg = local.postgres_databases[local.app]

  # --- one entry per app = its login role (creds in Vault secret/<vault_kv_path>)
  #     owning its databases. manage_secret defaults false = adopt existing creds. ---
  postgres_databases = {
    temporal          = { vault_kv_path = "temporal", databases = ["temporal", "temporal_visibility"], extensions = { temporal_visibility = ["btree_gin"] } }
    forgejo           = { vault_kv_path = "forgejo", databases = ["forgejo"] }
    trivy             = { vault_kv_path = "trivy-dashboard", databases = ["trivy"] }
    grafana           = { vault_kv_path = "grafana", databases = ["grafana"] }
    vaultwarden       = { vault_kv_path = "vaultwarden", databases = ["vaultwarden"] }
    g3                = { vault_kv_path = "g3", username_field = "db_user", databases = ["g3"] }
    "s3-orchestrator" = { vault_kv_path = "s3-orchestrator", databases = ["s3_orchestrator"] }
    "flight-fetcher"  = { vault_kv_path = "flight-fetcher", databases = ["flight_fetcher"] }
    sonarr            = { vault_kv_path = "sonarr", databases = ["sonarr_main", "sonarr_log"] }
    radarr            = { vault_kv_path = "radarr", databases = ["radarr_main", "radarr_log"] }
    lidarr            = { vault_kv_path = "lidarr", databases = ["lidarr_main", "lidarr_log"] }
    readarr           = { vault_kv_path = "readarr", databases = ["readarr_main", "readarr_log", "readarr-cache"] }
    prowlarr          = { vault_kv_path = "prowlarr", databases = ["prowlarr_main", "prowlarr_log"] }
  }
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
