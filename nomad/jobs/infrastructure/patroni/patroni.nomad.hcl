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
    max_parallel = 1
    # --- gate on the /health check (node rejoined as a Patroni member), not just
    #     container start; primary/replica routing checks are on_update=ignore ---
    health_check      = "checks"
    min_healthy_time  = "60s"
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

    # --- Run on ingress nodes only (meta.role=ingress), paired with haproxy ---
    constraint {
      attribute = "${meta.role}"
      operator  = "="
      value     = "ingress"
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
      port "metrics" {
        static = 9187
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
        # --- routing only (fails on replicas by design); don't gate deploys ---
        on_update = "ignore"
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
        # --- routing only (fails on the leader by design); don't gate deploys ---
        on_update = "ignore"
      }
    }

    # --- Patroni REST API ---
    service {
      name     = "patroni"
      port     = "patroni"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "metrics",
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
        # --- 3 consecutive misses (~30s) before HAProxy drops the backend ---
        # --- avoids gossip-induced single-miss flaps (see GH #130) ---
        success_before_passing   = 1
        failures_before_critical = 3
      }
    }

    # --- Postgres Metrics (for Prometheus) ---
    service {
      name     = "postgres-exporter"
      port     = "metrics"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "prometheus",
        "metrics",
        "postgres"
      ]

      check {
        name     = "postgres-exporter-health"
        type     = "http"
        port     = "metrics"
        path     = "/metrics"
        interval = "30s"
        timeout  = "5s"
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
        image   = "busybox:1.38.0"
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
      # WI token re-derives at the role's 24h max_ttl; noop so that token
      # cycle does not restart Postgres (a restart = a primary failover).
      vault {
        role        = "patroni"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image              = "registry.munchbox.cc/patroni:115bb0f6"
        image_pull_timeout = "10m"
        network_mode       = "host"

        volumes = [
          # Persistent data - use host path for durability
          "/opt/nomad/data/patroni-${NOMAD_ALLOC_INDEX}:/home/postgres/data",
          "local/patroni.yml:/etc/patroni/patroni.yml:ro"
          # --- No per-file bind for the TLS material: Postgres reads it out of
          # /secrets, the alloc secrets/ dir Nomad already mounts. A single-file
          # bind latches to the inode at container start, and consul-template
          # renders by rename, so every rotation would orphan the mount and
          # freeze the cert until the alloc was recreated. Same reason prometheus
          # reads its rules through /local. ---
        ]
      }

      # --- TLS Certificate from Vault PKI ---
      # Note: postgres user in Spilo container has UID/GID 999
      template {
        destination = "secrets/server.crt"
        # --- Reload Postgres in place on cert rotation (SIGHUP to postmaster);
        # a task restart here would fail the primary over. pg_ctl targets the
        # postmaster directly since PID 1 in the container is Patroni, not it. ---
        change_mode = "script"
        change_script {
          command       = "/bin/sh"
          args          = ["-c", "pg_ctl reload -D /home/postgres/data/pgdata"]
          timeout       = "30s"
          fail_on_error = false
        }
        perms = "0644"
        uid   = 999
        gid   = 999
        data  = <<-EOF
{{ with secret "pki_int/issue/postgres" "common_name=postgres.service.consul" "alt_names=postgres-primary.service.consul,postgres-replica.service.consul,haproxy-postgres.service.consul,localhost" "ip_sans=127.0.0.1" "ttl=2160h" }}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}
{{ end }}
        EOF
      }

      template {
        destination = "secrets/server.key"
        change_mode = "script"
        change_script {
          command       = "/bin/sh"
          args          = ["-c", "pg_ctl reload -D /home/postgres/data/pgdata"]
          timeout       = "30s"
          fail_on_error = false
        }
        perms = "0600"
        uid   = 999
        gid   = 999
        data  = <<-EOF
{{ with secret "pki_int/issue/postgres" "common_name=postgres.service.consul" "alt_names=postgres-primary.service.consul,postgres-replica.service.consul,haproxy-postgres.service.consul,localhost" "ip_sans=127.0.0.1" "ttl=2160h" }}
{{ .Data.private_key }}
{{ end }}
        EOF
      }

      template {
        destination = "secrets/ca.crt"
        change_mode = "script"
        change_script {
          command       = "/bin/sh"
          args          = ["-c", "pg_ctl reload -D /home/postgres/data/pgdata"]
          timeout       = "30s"
          fail_on_error = false
        }
        perms = "0644"
        uid   = 999
        gid   = 999
        data  = <<-EOF
{{ with secret "pki_int/cert/ca" }}
{{ .Data.certificate }}
{{ end }}
        EOF
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

    # --- TLS/SSL ---
    ssl: "on"
    ssl_cert_file: /secrets/server.crt
    ssl_key_file: /secrets/server.key
    ssl_ca_file: /secrets/ca.crt

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
    # Require TLS for all remote connections
    - hostssl all all 0.0.0.0/0 scram-sha-256
    - hostssl replication {{ with secret "secret/data/postgres-shared/replication" }}{{ .Data.data.username }}{{ end }} 0.0.0.0/0 scram-sha-256

# --- Bootstrap Configuration (for new cluster) ---
bootstrap:
  dcs:
    # ttl raised off the 30s floor (ttl >= loop_wait + 2*retry_timeout) so a
    # transient Consul-gossip storm from the WG-tunneled oracle nodes can't
    # expire the leader's DCS session and force a false failover (see README).
    # NOTE: bootstrap.dcs only seeds a NEW cluster; apply to the running one
    # with `patronictl edit-config`.
    ttl: 90
    loop_wait: 10
    retry_timeout: 15
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

# --- Tags for Consul service discovery ---
tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
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

    # -------------------------------------------------------------------------
    # Task: postgres-exporter (Prometheus metrics sidecar)
    # -------------------------------------------------------------------------

    task "postgres-exporter" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      # --- noop token cycle: exporter need not restart when the WI token rotates ---
      vault {
        role        = "patroni"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image        = "quay.io/prometheuscommunity/postgres-exporter:v0.20.1"
        network_mode = "host"
      }

      template {
        destination = "secrets/exporter.env"
        env         = true
        data        = <<-EOF
{{ with secret "secret/data/postgres-shared/root" }}
DATA_SOURCE_USER={{ .Data.data.username }}
DATA_SOURCE_PASS={{ .Data.data.password }}
DATA_SOURCE_URI=127.0.0.1:{{ env "NOMAD_PORT_postgres" }}/postgres?sslmode=require
{{ end }}
PG_EXPORTER_WEB_LISTEN_ADDRESS=:{{ env "NOMAD_PORT_metrics" }}
PG_EXPORTER_DISABLE_DEFAULT_METRICS=false
PG_EXPORTER_DISABLE_SETTINGS_METRICS=false
        EOF
      }

      resources {
        cpu    = 250
        memory = 64
      }
    }
  }
}
