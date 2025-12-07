# -------------------------------------------------------------------------------
# postgres-shared — Multi-tenant PostgreSQL Server
#
# Project: Munchbox / Author: Alex Freidah
#
# Shared PostgreSQL 16 instance for multiple services. Vault templates database
# credentials for each tenant into init scripts. Pinned to nomad-client-03 with
# local storage persistence.
# -------------------------------------------------------------------------------

job "postgres-shared" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 75

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Placement
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "nomad-client-03"
  }

  # ---------------------------------------------------------------------------
  # Task Group: postgres-shared
  # ---------------------------------------------------------------------------

  group "postgres-shared" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "postgres" {
        static = 5432
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # --- Service Registration ---
    service {
      name     = "postgres-shared"
      port     = "postgres"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "database",
        "postgres",
        "shared"
      ]

      check {
        name     = "postgres-tcp"
        type     = "tcp"
        port     = "postgres"
        interval = "10s"
        timeout  = "3s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: init-storage
    # -------------------------------------------------------------------------

    task "init-storage" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image   = "busybox:latest"
        command = "sh"
        args    = ["-c", "mkdir -p /init-data && chown -R 70:70 /init-data && chmod 700 /init-data"]
        volumes = ["/opt/nomad/data/postgres-shared:/init-data"]
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    # -------------------------------------------------------------------------
    # Task: postgres
    # -------------------------------------------------------------------------

    task "postgres" {
      driver = "docker"

      # --- Vault Integration ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image        = "postgres:16-alpine"
        network_mode = "host"
        ports        = ["postgres"]
        volumes      = [
          "/opt/nomad/data/postgres-shared:/var/lib/postgresql/data",
          "local/init-nextcloud.sql:/docker-entrypoint-initdb.d/10-nextcloud.sql:ro",
          "local/init-temporal.sql:/docker-entrypoint-initdb.d/20-temporal.sql:ro"
        ]
      }

      # --- Root Credentials from Vault ---
      template {
        destination = "secrets/postgres.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
{{ with secret "secret/data/postgres-shared/root" }}
POSTGRES_USER={{ .Data.data.username }}
POSTGRES_PASSWORD={{ .Data.data.password }}
{{ end }}
EOH
      }

      # --- Nextcloud Database Init ---
      template {
        destination = "local/init-nextcloud.sql"
        change_mode = "noop"
        data        = <<EOH
-- Nextcloud database and user (credentials from Vault)
{{ with secret "secret/data/nextcloud" }}
CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
CREATE DATABASE nextcloud OWNER {{ .Data.data.db_username }};
GRANT ALL PRIVILEGES ON DATABASE nextcloud TO {{ .Data.data.db_username }};
\c nextcloud
GRANT ALL ON SCHEMA public TO {{ .Data.data.db_username }};
{{ end }}
EOH
      }

      # --- Temporal Database Init ---
      template {
        destination = "local/init-temporal.sql"
        change_mode = "noop"
        data        = <<EOH
      CREATE USER temporal WITH ENCRYPTED PASSWORD 'temporal';
      CREATE DATABASE temporal OWNER temporal;
      CREATE DATABASE temporal_visibility OWNER temporal;
      \c temporal
      GRANT ALL ON SCHEMA public TO temporal;
      \c temporal_visibility
      GRANT ALL ON SCHEMA public TO temporal;
      EOH
      }

      # --- Environment ---
      env {
        PGDATA = "/var/lib/postgresql/data/pgdata"
        TZ     = "America/Los_Angeles"
      }

      # --- Resources ---
      resources {
        cpu    = 500
        memory = 512
      }

      # --- Termination ---
      kill_timeout = "60s"
      kill_signal  = "SIGTERM"
    }
  }
}
