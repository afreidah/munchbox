# -------------------------------------------------------------------------------
# g3-proxy — S3-Compatible Gateway Backed by Gmail and Google Drive
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs the g3 S3 gateway as a Nomad service. Stores object data in Google
# Drive and metadata in Gmail with a PostgreSQL metadata index on the
# shared Patroni cluster. Credentials are injected from Vault.
# -------------------------------------------------------------------------------

job "g3-proxy" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "default"
  priority    = 40

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Placement: keep off ingress nodes (goren/stabler)
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${meta.role}"
    operator  = "!="
    value     = "ingress"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    canary            = 0
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: g3-proxy
  # ---------------------------------------------------------------------------

  group "g3-proxy" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
        static = 9001
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
      name     = "g3-proxy"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.g3-proxy.rule=Host(`g3-proxy.munchbox.cc`)",
        "traefik.http.routers.g3-proxy.entrypoints=websecure",
        "traefik.http.routers.g3-proxy.tls=true",
        "traefik.http.services.g3-proxy.loadbalancer.server.port=9001",
        "infrastructure",
        "g3",
        "storage",
        "traefik.http.routers.g3-proxy.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
        "traefik.http.routers.g3-proxy-http.rule=Host(`g3-proxy.munchbox.cc`)",
        "traefik.http.routers.g3-proxy-http.entrypoints=web",
        "traefik.http.routers.g3-proxy-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file",
      ]

      check {
        name      = "g3-proxy-health"
        type      = "http"
        path      = "/health/ready"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: g3-proxy
    # -------------------------------------------------------------------------

    task "g3-proxy" {
      driver = "docker"

      vault {
        role        = "nomad-workloads"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image              = "registry.munchbox.cc/g3:v0.5.6"
        image_pull_timeout = "10m"
        ports              = ["http"]
        network_mode       = "host"
        args               = ["-config", "/secrets/config.yaml"]
      }

      # --- Environment ---
      env {
        TZ         = "America/Los_Angeles"
        GOMAXPROCS = "1"
        GOMEMLIMIT = "700MiB"
      }

      # --- Configuration Template ---
      template {
        data        = <<EOH
{{ with secret "secret/data/g3" }}
server:
  listen_addr: "0.0.0.0:9001"
  log_level: "info"
  read_timeout: "20m"
  write_timeout: "20m"

gmail:
  client_id: "{{ .Data.data.client_id }}"
  client_secret: "{{ .Data.data.client_secret }}"
  refresh_token: "{{ .Data.data.refresh_token }}"
  label_prefix: "s3"

database:
  driver: "postgres"
  host: "haproxy-postgres.service.consul"
  port: 5433
  database: "g3"
  user: "{{ .Data.data.db_user }}"
  password: "{{ .Data.data.db_password }}"
  ssl_mode: "require"
  max_conns: 5

buckets:
  - name: "{{ .Data.data.bucket }}"
    credentials:
      - access_key_id: "{{ .Data.data.s3_access_key }}"
        secret_access_key: "{{ .Data.data.s3_secret_key }}"

telemetry:
  metrics:
    enabled: true
    path: "/metrics"
  tracing:
    enabled: true
    endpoint: "tempo.service.consul:4317"
    insecure: true
    sample_rate: 1.0
{{ end }}
EOH
        destination = "secrets/config.yaml"
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu        = 150
        memory     = 96
        memory_max = 1536
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
