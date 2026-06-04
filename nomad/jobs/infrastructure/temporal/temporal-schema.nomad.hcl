# -------------------------------------------------------------------------------
# Temporal Schema Migration - one-shot batch job
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs temporal-sql-tool update-schema against the Patroni/Postgres backend
# (reached via the haproxy-postgres Consul DNS name, TLS with the Vault PKI CA)
# for both the `temporal` and `temporal_visibility` databases.
#
# Temporal only supports sequential minor upgrades, so the flow is:
#   1. set the admin-tools image tag below to the NEXT server minor
#   2. run this job (make run JOB=temporal-schema) and confirm it completes
#   3. bump temporal-server.hcl to the same version and deploy it
#   4. repeat for the following minor
# The image tag here == the schema version being migrated TO.
# -------------------------------------------------------------------------------

job "temporal-schema" {
  datacenters = ["munchbox"]
  type        = "batch"

  group "migrate" {
    count = 1

    # --- one-shot: surface failures, don't loop ---
    restart {
      attempts = 0
      mode     = "fail"
    }
    reschedule {
      attempts  = 0
      unlimited = false
    }

    task "update-schema" {
      driver = "docker"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image        = "temporalio/admin-tools:1.31.0"
        network_mode = "host"
        command      = "sh"
        args = ["-c",
          "set -eu; temporal-sql-tool --db temporal update-schema -d /etc/temporal/schema/postgresql/v12/temporal/versioned && temporal-sql-tool --db temporal_visibility update-schema -d /etc/temporal/schema/postgresql/v12/visibility/versioned"
        ]
      }

      # --- Postgres TLS CA (Vault PKI), same source as the server's ca.crt ---
      template {
        destination = "secrets/ca.crt"
        data        = <<EOF
{{ with secret "pki_int/cert/ca" }}{{ .Data.certificate }}{{ end }}
{{ with secret "pki/cert/ca" }}{{ .Data.certificate }}{{ end }}
EOF
      }

      # --- temporal-sql-tool connection settings (env-var form of the CLI flags) ---
      template {
        destination = "secrets/migrate.env"
        env         = true
        data        = <<EOF
{{ with secret "secret/data/temporal" -}}
SQL_PLUGIN=postgres12_pgx
SQL_HOST=haproxy-postgres.service.consul
SQL_PORT=5433
SQL_USER={{ .Data.data.db_username }}
SQL_PASSWORD={{ .Data.data.db_password }}
SQL_TLS=true
SQL_TLS_CA_FILE=/secrets/ca.crt
SQL_TLS_DISABLE_HOST_VERIFICATION=true
{{- end }}
EOF
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
