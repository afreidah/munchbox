# -------------------------------------------------------------------------------
# Trivy Dashboard — Vulnerability Scan Report Viewer
#
# Project: Munchbox / Author: Alex Freidah
#
# Web dashboard that displays Trivy vulnerability scan reports from PostgreSQL.
# Reads from postgres-replica for read-only queries. Provides color-coded
# severity visualization and Prometheus metrics.
# -------------------------------------------------------------------------------

job "trivy-dashboard" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 30

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------
  update {
    max_parallel      = 1
    canary            = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "2m"
    progress_deadline = "5m"
    auto_revert       = true
    auto_promote      = true
  }

  # -------------------------------------------------------------------------
  # Placement - no constraint, can run on any node
  # -------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Task Group: dashboard
  # ---------------------------------------------------------------------------

  group "dashboard" {
    count = 1

    network {
      mode = "host"
      port "http" {
        static = 8080
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    service {
      name     = "trivy-dashboard"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.trivy-dashboard.rule=Host(`trivy-dashboard.munchbox.cc`)",
        "traefik.http.routers.trivy-dashboard.entrypoints=websecure",
        "traefik.http.routers.trivy-dashboard.tls.certresolver=letsencrypt",
        "traefik.http.routers.trivy-dashboard.middlewares=oauth2-proxy@file,umami-tracking@file",
        # HTTP router for CF tunnel
        "traefik.http.routers.trivy-dashboard-http.rule=Host(`trivy-dashboard.munchbox.cc`)",
        "traefik.http.routers.trivy-dashboard-http.entrypoints=web",
        "traefik.http.routers.trivy-dashboard-http.middlewares=cf-tunnel-https@file,oauth2-proxy@file,umami-tracking@file",
      ]

      check {
        name     = "http-health"
        type     = "http"
        path     = "/health"
        interval = "15s"
        timeout  = "5s"
      }
    }

    task "dashboard" {
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
        image              = "registry.munchbox.cc/trivy-dashboard:latest"
        image_pull_timeout = "5m"
        ports              = ["http"]
        volumes            = ["secrets/ca.crt:/etc/ssl/postgres/ca.crt:ro"]
      }

      # PostgreSQL CA certificate for TLS verification
      template {
        destination = "secrets/ca.crt"
        perms       = "0644"
        data        = <<-EOF
{{ with secret "pki_int/cert/ca" }}
{{ .Data.certificate }}
{{ end }}
        EOF
      }

      secret "trivy_db" {
        provider = "vault"
        path     = "secret/data/trivy-dashboard"
        config {
          engine = "kv_v2"
        }
      }

      env {
        PORT                        = "8080"
        TRIVY_DB_HOST               = "postgres-primary.service.consul"
        TRIVY_DB_PORT               = "5432"
        TRIVY_DB_USER               = "${secret.trivy_db.db_username}"
        TRIVY_DB_PASSWORD           = "${secret.trivy_db.db_password}"
        TRIVY_DB_NAME               = "trivy"
        DB_SSLMODE                  = "verify-ca"
        DB_SSLROOTCERT              = "/etc/ssl/postgres/ca.crt"
        TEMPORAL_ADDRESS            = "temporal-server.service.consul:7233"
        # OpenTelemetry tracing to Tempo (gRPC)
        OTEL_EXPORTER_OTLP_ENDPOINT = "tempo.service.consul:4317"
        OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    project = "munchbox"
  }
}
