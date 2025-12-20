# -------------------------------------------------------------------------------
# postgres-shared — Multi-tenant PostgreSQL Server (Primary)
#
# Project: Munchbox / Author: Alex Freidah
#
# Shared PostgreSQL 16 instance for multiple services. Vault templates database
# credentials for each tenant into init scripts. Pinned to nomad-client-03 with
# local storage persistence. Configured for streaming replication to replica.
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

      deregister_critical_service_after = "1m"
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
        image   = "busybox:1.37.0"
        command = "sh"
        args    = ["-c", "mkdir -p /init-data && chown -R 70:70 /init-data && chmod 700 /init-data"]
        volumes = ["/opt/nomad/data/postgres-shared:/init-data"]
      }

      resources {
        cpu    = 200
        memory = 1024
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
          "local/init-temporal.sql:/docker-entrypoint-initdb.d/20-temporal.sql:ro",
          "local/init-trivy.sql:/docker-entrypoint-initdb.d/30-trivy.sql:ro",
          "local/init-woodpecker.sql:/docker-entrypoint-initdb.d/40-woodpecker.sql:ro",
          "local/init-forgejo.sql:/docker-entrypoint-initdb.d/50-forgejo.sql:ro",
          "local/init-umami.sql:/docker-entrypoint-initdb.d/60-umami.sql:ro"
        ]

        # PostgreSQL replication settings (enable streaming replication)
        args = [
          "-c", "wal_level=replica",
          "-c", "max_wal_senders=3",
          "-c", "max_replication_slots=3",
          "-c", "hot_standby=on",
          "-c", "wal_keep_size=256MB"
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
{{ with secret "secret/data/temporal" }}
CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
CREATE DATABASE temporal OWNER {{ .Data.data.db_username }};
CREATE DATABASE temporal_visibility OWNER {{ .Data.data.db_username }};
\c temporal
GRANT ALL ON SCHEMA public TO {{ .Data.data.db_username }};
\c temporal_visibility
GRANT ALL ON SCHEMA public TO {{ .Data.data.db_username }};
{{ end }}
EOH
      }

      # --- Trivy Dashboard Database Init ---
      template {
        destination = "local/init-trivy.sql"
        change_mode = "noop"
        data        = <<EOH
{{ with secret "secret/data/trivy-dashboard" }}
CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
CREATE DATABASE trivy OWNER {{ .Data.data.db_username }};
\c trivy
GRANT ALL ON SCHEMA public TO {{ .Data.data.db_username }};

-- Scan results table
CREATE TABLE scans (
    id SERIAL PRIMARY KEY,
    image TEXT NOT NULL,
    status TEXT NOT NULL,
    error TEXT,
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Vulnerabilities table
CREATE TABLE vulnerabilities (
    id SERIAL PRIMARY KEY,
    scan_id INTEGER REFERENCES scans(id) ON DELETE CASCADE,
    vuln_id TEXT NOT NULL,
    severity TEXT NOT NULL,
    pkg_name TEXT,
    installed_version TEXT,
    fixed_version TEXT,
    title TEXT,
    description TEXT
);

-- Indexes for common queries
CREATE INDEX idx_scans_image ON scans(image);
CREATE INDEX idx_scans_scanned_at ON scans(scanned_at DESC);
CREATE INDEX idx_vulns_scan_id ON vulnerabilities(scan_id);
CREATE INDEX idx_vulns_severity ON vulnerabilities(severity);

GRANT ALL ON ALL TABLES IN SCHEMA public TO {{ .Data.data.db_username }};
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO {{ .Data.data.db_username }};
{{ end }}
EOH
      }

      # --- Woodpecker CI Database Init ---
      template {
        destination = "local/init-woodpecker.sql"
        change_mode = "noop"
        data        = <<EOH
{{ with secret "secret/data/woodpecker" }}
CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
CREATE DATABASE woodpecker OWNER {{ .Data.data.db_username }};
\c woodpecker
GRANT ALL ON SCHEMA public TO {{ .Data.data.db_username }};
{{ end }}
EOH
      }

      # --- Forgejo Database Init ---
      template {
        destination = "local/init-forgejo.sql"
        change_mode = "noop"
        data        = <<EOH
{{ with secret "secret/data/forgejo" }}
CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
CREATE DATABASE forgejo OWNER {{ .Data.data.db_username }};
\c forgejo
GRANT ALL ON SCHEMA public TO {{ .Data.data.db_username }};
{{ end }}
EOH
      }

      # --- Umami Database Init ---
      template {
        destination = "local/init-umami.sql"
        change_mode = "noop"
        data        = <<EOH
{{ with secret "secret/data/umami" }}
CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
CREATE DATABASE umami OWNER {{ .Data.data.db_username }};
\c umami
GRANT ALL ON SCHEMA public TO {{ .Data.data.db_username }};
{{ end }}
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
