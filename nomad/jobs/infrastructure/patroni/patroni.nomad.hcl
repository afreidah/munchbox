# -------------------------------------------------------------------------------
# Patroni — High Availability PostgreSQL Cluster
#
# Project: Munchbox / Author: Alex Freidah
#
# Patroni manages a PostgreSQL 18 cluster with automatic failover. Uses Consul
# for leader election and cluster state. Replaces the manual postgres-shared
# and postgres-replica jobs with a self-healing HA cluster.
# -------------------------------------------------------------------------------

job "patroni" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 80

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
    health_check      = "task_states"
    min_healthy_time  = "30s"
    healthy_deadline  = "10m"
    progress_deadline = "15m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: patroni
  #
  # Runs on multiple nodes. Patroni handles leader election via Consul.
  # Only one instance is primary at a time; others are streaming replicas.
  # ---------------------------------------------------------------------------

  group "patroni" {
    count = 2

    # --- Spread across different nodes for HA ---
    spread {
      attribute = "${node.unique.name}"
      weight    = 100
    }

    # --- Prevent multiple instances on same node ---
    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    # --- Network Configuration ---
    network {
      mode = "host"
      port "postgres" {
        static = 5432
      }
      port "patroni" {
        static = 8008
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
      delay          = "10s"
      delay_function = "exponential"
      max_delay      = "2m"
      unlimited      = false
    }

    # --- Primary Service (only healthy on leader) ---
    service {
      name     = "postgres-primary"
      port     = "postgres"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "database",
        "postgres",
        "primary",
        "patroni"
      ]

      # Patroni REST API returns role info
      check {
        name     = "patroni-primary"
        type     = "http"
        port     = "patroni"
        path     = "/primary"
        interval = "5s"
        timeout  = "2s"
      }
    }

    # --- Replica Service (healthy on replicas) ---
    service {
      name     = "postgres-replica"
      port     = "postgres"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "database",
        "postgres",
        "replica",
        "read-only",
        "patroni"
      ]

      check {
        name     = "patroni-replica"
        type     = "http"
        port     = "patroni"
        path     = "/replica"
        interval = "5s"
        timeout  = "2s"
      }
    }

    # --- Patroni REST API ---
    service {
      name     = "patroni"
      port     = "patroni"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "patroni",
        "api"
      ]

      check {
        name     = "patroni-health"
        type     = "http"
        port     = "patroni"
        path     = "/health"
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
        image   = "busybox:1.37.0"
        command = "sh"
        args    = ["-c", "mkdir -p /data/pgdata && chown -R 999:999 /data && chmod 700 /data/pgdata"]
        volumes = ["/opt/nomad/data/patroni-${NOMAD_ALLOC_INDEX}:/data"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    # -------------------------------------------------------------------------
    # Task: patroni
    # -------------------------------------------------------------------------

    task "patroni" {
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
        image              = "registry.munchbox.cc/patroni:pg18"
        image_pull_timeout = "10m"
        network_mode       = "host"

        volumes = [
          # Persistent data - use host path for durability
          "/opt/nomad/data/patroni-${NOMAD_ALLOC_INDEX}:/home/postgres/data",
          "local/patroni.yml:/etc/patroni/patroni.yml:ro",
          "local/post-init.sh:/etc/patroni/post-init.sh:ro"
        ]
      }

      # --- Patroni Configuration ---
      template {
        destination = "local/patroni.yml"
        change_mode = "restart"
        data        = <<-EOF
scope: munchbox-postgres
name: pg-{{ env "NOMAD_ALLOC_INDEX" }}-{{ index (env "node.unique.name" | split ".") 0 }}

# --- Consul DCS Configuration ---
consul:
  host: consul.service.consul:8500
  token: {{ with secret "secret/data/patroni" }}{{ .Data.data.consul_token }}{{ end }}
  register_service: false  # We use Nomad's service stanza instead

# --- REST API ---
restapi:
  listen: 0.0.0.0:{{ env "NOMAD_PORT_patroni" }}
  connect_address: {{ env "NOMAD_IP_patroni" }}:{{ env "NOMAD_PORT_patroni" }}

# --- PostgreSQL Configuration ---
postgresql:
  listen: 0.0.0.0:{{ env "NOMAD_PORT_postgres" }}
  connect_address: {{ env "NOMAD_IP_postgres" }}:{{ env "NOMAD_PORT_postgres" }}
  data_dir: /home/postgres/data/pgdata
  bin_dir: /usr/lib/postgresql/18/bin
  pgpass: /tmp/pgpass

  authentication:
    superuser:
      username: {{ with secret "secret/data/postgres-shared/root" }}{{ .Data.data.username }}{{ end }}
      password: {{ with secret "secret/data/postgres-shared/root" }}{{ .Data.data.password }}{{ end }}
    replication:
      username: {{ with secret "secret/data/postgres-shared/replication" }}{{ .Data.data.username }}{{ end }}
      password: {{ with secret "secret/data/postgres-shared/replication" }}{{ .Data.data.password }}{{ end }}
    rewind:
      username: {{ with secret "secret/data/postgres-shared/root" }}{{ .Data.data.username }}{{ end }}
      password: {{ with secret "secret/data/postgres-shared/root" }}{{ .Data.data.password }}{{ end }}

  parameters:
    # --- Connection Settings ---
    max_connections: 100

    # --- Memory ---
    shared_buffers: 256MB
    effective_cache_size: 768MB
    work_mem: 4MB
    maintenance_work_mem: 64MB

    # --- WAL ---
    wal_level: replica
    max_wal_senders: 5
    max_replication_slots: 5
    wal_keep_size: 256MB

    # --- Replication ---
    hot_standby: "on"
    hot_standby_feedback: "on"

    # --- Logging ---
    log_destination: stderr
    logging_collector: "off"
    log_min_messages: warning
    log_connections: "on"
    log_disconnections: "on"

    # --- Timezone ---
    timezone: America/Los_Angeles

  pg_hba:
    - local all all trust
    - host all all 127.0.0.1/32 scram-sha-256
    - host all all 0.0.0.0/0 scram-sha-256
    - host replication {{ with secret "secret/data/postgres-shared/replication" }}{{ .Data.data.username }}{{ end }} 0.0.0.0/0 scram-sha-256

# --- Bootstrap Configuration (for new cluster) ---
bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576  # 1MB
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        max_connections: 100
        shared_buffers: 256MB

  # --- Initial database setup ---
  initdb:
    - encoding: UTF8
    - locale: en_US.UTF-8
    - data-checksums

  # --- Post-init SQL scripts ---
  post_init: /etc/patroni/post-init.sh

# --- Tags for Consul service discovery ---
tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
        EOF
      }

      # --- Post-init script for creating databases ---
      template {
        destination = "local/post-init.sh"
        perms       = "755"
        data        = <<-EOF
#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
until pg_isready -h localhost -p {{ env "NOMAD_PORT_postgres" }}; do
  sleep 1
done

{{ with secret "secret/data/postgres-shared/root" }}
export PGPASSWORD='{{ .Data.data.password }}'
PGUSER='{{ .Data.data.username }}'
{{ end }}

# --- Create application databases ---
psql -h localhost -p {{ env "NOMAD_PORT_postgres" }} -U $PGUSER -d postgres <<SQL

-- Nextcloud
{{ with secret "secret/data/nextcloud" }}
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '{{ .Data.data.db_username }}') THEN
    CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
  END IF;
END
\$\$;
CREATE DATABASE IF NOT EXISTS nextcloud OWNER {{ .Data.data.db_username }};
{{ end }}

-- Temporal
{{ with secret "secret/data/temporal" }}
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '{{ .Data.data.db_username }}') THEN
    CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
  END IF;
END
\$\$;
CREATE DATABASE IF NOT EXISTS temporal OWNER {{ .Data.data.db_username }};
CREATE DATABASE IF NOT EXISTS temporal_visibility OWNER {{ .Data.data.db_username }};
{{ end }}

-- Woodpecker
{{ with secret "secret/data/woodpecker" }}
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '{{ .Data.data.db_username }}') THEN
    CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
  END IF;
END
\$\$;
CREATE DATABASE IF NOT EXISTS woodpecker OWNER {{ .Data.data.db_username }};
{{ end }}

-- Forgejo
{{ with secret "secret/data/forgejo" }}
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '{{ .Data.data.db_username }}') THEN
    CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
  END IF;
END
\$\$;
CREATE DATABASE IF NOT EXISTS forgejo OWNER {{ .Data.data.db_username }};
{{ end }}

-- Umami
{{ with secret "secret/data/umami" }}
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '{{ .Data.data.db_username }}') THEN
    CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
  END IF;
END
\$\$;
CREATE DATABASE IF NOT EXISTS umami OWNER {{ .Data.data.db_username }};
{{ end }}

-- Trivy Dashboard
{{ with secret "secret/data/trivy-dashboard" }}
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '{{ .Data.data.db_username }}') THEN
    CREATE USER {{ .Data.data.db_username }} WITH ENCRYPTED PASSWORD '{{ .Data.data.db_password }}';
  END IF;
END
\$\$;
CREATE DATABASE IF NOT EXISTS trivy OWNER {{ .Data.data.db_username }};
{{ end }}

SQL

echo "Database initialization complete"
        EOF
      }

      # --- Environment ---
      env {
        PATRONI_CONFIGURATION = "/etc/patroni/patroni.yml"
        TZ                    = "America/Los_Angeles"
      }

      # --- Resources ---
      resources {
        cpu    = 500
        memory = 1024
      }

      # --- Termination ---
      kill_timeout = "60s"
      kill_signal  = "SIGTERM"
    }
  }
}
