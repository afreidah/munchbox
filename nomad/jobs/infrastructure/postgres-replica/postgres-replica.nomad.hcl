# -------------------------------------------------------------------------------
# postgres-replica — PostgreSQL Streaming Replica
#
# Project: Munchbox / Author: Alex Freidah
#
# Hot standby replica of postgres-shared primary. Uses streaming replication
# with pg_basebackup for initial sync. Pinned to nomad-client-02 to ensure
# data redundancy across different nodes.
# -------------------------------------------------------------------------------

job "postgres-replica" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 70

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
    healthy_deadline  = "10m"
    progress_deadline = "15m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Placement - Different node from primary
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "nomad-client-02"
  }

  # ---------------------------------------------------------------------------
  # Task Group: postgres-replica
  # ---------------------------------------------------------------------------

  group "postgres-replica" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "postgres" {
        static = 5433
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
      name     = "postgres-replica"
      port     = "postgres"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "database",
        "postgres",
        "replica",
        "read-only"
      ]

      check {
        name     = "postgres-replica-tcp"
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
        image   = "busybox:latest"
        command = "sh"
        args    = ["-c", "mkdir -p /init-data && chown -R 70:70 /init-data && chmod 700 /init-data"]
        volumes = ["/opt/nomad/data/postgres-replica:/init-data"]
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }

    # -------------------------------------------------------------------------
    # Task: basebackup (initial sync from primary)
    # -------------------------------------------------------------------------

    task "basebackup" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

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
        image   = "postgres:16-alpine"
        command = "/bin/sh"
        args    = ["-c", "/scripts/init-replica.sh"]
        volumes = [
          "/opt/nomad/data/postgres-replica:/var/lib/postgresql/data",
          "local/init-replica.sh:/scripts/init-replica.sh:ro"
        ]
      }

      template {
        destination = "local/init-replica.sh"
        perms       = "755"
        data        = <<EOH
#!/bin/sh
set -e

PGDATA="/var/lib/postgresql/data/pgdata"
PRIMARY_HOST="postgres-shared.service.consul"

# Check if data directory already has data (replica already initialized)
if [ -f "$PGDATA/PG_VERSION" ]; then
  echo "Replica data directory already exists, skipping basebackup"
  exit 0
fi

echo "Initializing replica from primary at $PRIMARY_HOST..."

# Clean any partial data
rm -rf "$PGDATA"/*

# Run pg_basebackup
{{ with secret "secret/data/postgres-shared/replication" }}
PGPASSWORD='{{ .Data.data.password }}' pg_basebackup \
  -h "$PRIMARY_HOST" \
  -p 5432 \
  -U {{ .Data.data.username }} \
  -D "$PGDATA" \
  -Fp \
  -Xs \
  -P \
  -R \
  -S replica_slot
{{ end }}

# Ensure correct permissions
chown -R 70:70 /var/lib/postgresql/data
chmod 700 "$PGDATA"

echo "Base backup completed successfully"
EOH
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    # -------------------------------------------------------------------------
    # Task: postgres (replica)
    # -------------------------------------------------------------------------

    task "postgres" {
      driver = "docker"

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
          "/opt/nomad/data/postgres-replica:/var/lib/postgresql/data"
        ]

        # PostgreSQL replica settings
        args = [
          "-c", "port=5433",
          "-c", "hot_standby=on",
          "-c", "hot_standby_feedback=on",
          "-c", "primary_conninfo=host=postgres-shared.service.consul port=5432 user=replicator password=${REPL_PASSWORD}",
          "-c", "primary_slot_name=replica_slot"
        ]
      }

      # --- Replication credentials ---
      template {
        destination = "secrets/replica.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
{{ with secret "secret/data/postgres-shared/replication" }}
REPL_PASSWORD={{ .Data.data.password }}
{{ end }}
{{ with secret "secret/data/postgres-shared/root" }}
POSTGRES_USER={{ .Data.data.username }}
POSTGRES_PASSWORD={{ .Data.data.password }}
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
        cpu    = 300
        memory = 384
      }

      # --- Termination ---
      kill_timeout = "60s"
      kill_signal  = "SIGTERM"
    }
  }
}
