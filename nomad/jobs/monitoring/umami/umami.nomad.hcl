# -------------------------------------------------------------------------------
# Umami — Privacy-Focused Web Analytics
#
# Project: Munchbox / Author: Alex Freidah
#
# Umami provides simple, privacy-friendly website analytics with city-level
# geolocation tracking. Uses PostgreSQL for storage and requires only a small
# JS snippet on tracked sites.
# -------------------------------------------------------------------------------

# --- Shared Variables (from shared.vars.hcl) ---
variable "pihole_1" { type = string }
variable "pihole_2" { type = string }

job "umami" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 50

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
    canary            = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: umami
  # ---------------------------------------------------------------------------

  group "umami" {
    count = 1

    # --- Run on on-prem nodes (Oracle nodes have connectivity issues to postgres) ---
    constraint {
      attribute = "${meta.cloud}"
      operator  = "!="
      value     = "oracle"
    }

    # --- Network Configuration ---
    network {
      mode = "bridge"
      port "http" {
        to = 3000
      }
      # Bridge mode containers need explicit DNS config for Consul resolution
      # Uses node's dnsmasq (via CoreDNS) with Pi-hole fallbacks
      dns {
        servers  = ["${attr.unique.network.ip-address}", var.pihole_1, var.pihole_2]
        searches = ["service.consul"]
        options  = ["ndots:1", "timeout:2", "attempts:2"]
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "1h"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "10m"
      unlimited      = false
    }

    # --- Service Registration ---
    service {
      name     = "umami"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        # HTTPS router (direct LAN access)
        "traefik.http.routers.umami.rule=Host(`analytics.munchbox.cc`) || Host(`analytics.alexfreidah.com`)",
        "traefik.http.routers.umami.entrypoints=websecure",
        "traefik.http.routers.umami.tls=true",
        # HTTP router (Cloudflare tunnel)
        "traefik.http.routers.umami-http.rule=Host(`analytics.munchbox.cc`) || Host(`analytics.alexfreidah.com`)",
        "traefik.http.routers.umami-http.entrypoints=web",
        "traefik.http.routers.umami-http.middlewares=cf-tunnel-https@file",
        "analytics",
        "umami",
        "monitoring"
      ]

      check {
        name      = "umami-health"
        type      = "http"
        path      = "/api/heartbeat"
        interval  = "10s"
        timeout   = "5s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: geoip-updater (prestart)
    # Downloads DB-IP GeoLite City database for city-level geolocation
    # Uses DB-IP free database - no account or license key required
    # -------------------------------------------------------------------------

    task "geoip-updater" {
      driver = "docker"
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "alpine/curl:8.17.0"
        command = "/bin/sh"
        args    = ["-c", "cd /alloc/data && curl -sL \"https://download.db-ip.com/free/dbip-city-lite-$(date +%Y-%m).mmdb.gz\" | gunzip > dbip-city-lite.mmdb && ls -la"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    # -------------------------------------------------------------------------
    # Task: umami
    # -------------------------------------------------------------------------

    task "umami" {
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

      # --- Container Configuration ---
      config {
        image              = "ghcr.io/umami-software/umami:3.0.3"
        image_pull_timeout = "10m"
        ports              = ["http"]
      }

      # --- Vault CA Certificate Chain for PostgreSQL TLS ---
      template {
        destination = "secrets/ca.crt"
        change_mode = "restart"
        perms       = "0644"
        data        = <<-EOF
{{ with secret "pki_int/cert/ca" }}{{ .Data.certificate }}{{ end }}
{{ with secret "pki/cert/ca" }}{{ .Data.certificate }}{{ end }}
        EOF
      }

      # --- Environment Variables from Vault ---
      template {
        destination = "secrets/umami.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
{{ with secret "secret/data/umami" }}
DATABASE_URL=postgresql://{{ .Data.data.db_username }}:{{ .Data.data.db_password }}@haproxy-postgres.service.consul:5433/umami?sslmode=require
APP_SECRET={{ .Data.data.app_secret }}
{{ end }}
# Vault CA cert for PostgreSQL TLS verification
NODE_EXTRA_CA_CERTS={{ env "NOMAD_SECRETS_DIR" }}/ca.crt
# App URL for external access
APP_URL=https://analytics.munchbox.cc
# GeoIP database for city-level geolocation (DB-IP free database, downloaded by prestart task)
GEOIP_DATABASE_FILE=/alloc/data/dbip-city-lite.mmdb
# OpenTelemetry tracing to Tempo
OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo.service.consul:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_SERVICE_NAME=umami
EOH
      }

      # --- Resources ---
      resources {
        cpu    = 512
        memory = 512
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
