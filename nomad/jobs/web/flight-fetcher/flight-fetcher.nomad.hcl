# -------------------------------------------------------------------------------
# flight-fetcher - Munchbox Deployment
#
# Project: Flight Fetcher / Author: Alex Freidah
#
# Polls OpenSky Network for aircraft within a configurable radius, enriches
# metadata via HexDB.io and routes via AirLabs, stores current state in Redis
# and history in Postgres. Dashboard available on port 8080.
# -------------------------------------------------------------------------------

job "flight-fetcher" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "default"

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    canary            = 0
    health_check      = "task_states"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: flight-fetcher
  # ---------------------------------------------------------------------------

  group "flight-fetcher" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
        static = 8080
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
      name     = "flight-fetcher"
      port     = "http"
      provider = "consul"

      check {
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.flight-fetcher.rule=Host(`flights.munchbox.cc`)",
        "traefik.http.routers.flight-fetcher.entrypoints=websecure",
        "traefik.http.routers.flight-fetcher.tls=true",
        "traefik.http.routers.flight-fetcher.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
        "traefik.http.services.flight-fetcher.loadbalancer.server.port=8080",
        "traefik.http.routers.flight-fetcher-http.rule=Host(`flights.munchbox.cc`)",
        "traefik.http.routers.flight-fetcher-http.entrypoints=web",
        "traefik.http.routers.flight-fetcher-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file",
        "media",
        "flight-fetcher",
      ]
    }

    # -------------------------------------------------------------------------
    # Task: flight-fetcher
    # -------------------------------------------------------------------------

    task "flight-fetcher" {
      driver = "docker"

      vault {
        role = "flight-fetcher"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "registry.munchbox.cc/flight-fetcher:v0.9.25"
        image_pull_timeout = "10m"
        ports              = ["http"]
        network_mode       = "host"
        args               = ["-config", "/secrets/config.hcl", "-log-level", "info"]
        volumes            = ["secrets/config.hcl:/secrets/config.hcl:ro"]
      }

      env {
        TZ                             = "America/Los_Angeles"
        GOMAXPROCS                     = "1"
        GOMEMLIMIT                     = "96MiB"
        OTEL_EXPORTER_OTLP_ENDPOINT    = "http://tempo.service.consul:4317"
        OTEL_EXPORTER_OTLP_INSECURE    = "true"
      }

      # --- Configuration rendered by Vault ---
      template {
        data        = <<EOH
{{ with secret "secret/data/flight-fetcher" }}
location {
  lat       = 34.0928
  lon       = -118.3287
  radius_km = 200.0
}

opensky {
  id            = "{{ .Data.data.opensky_id }}"
  secret        = "{{ .Data.data.opensky_secret }}"
  poll_interval = "240s"
}

dump1090 {
  url           = "http://192.168.68.79/skyaware"
  poll_interval = "5s"
}

airlabs {
  api_key = "{{ .Data.data.airlabs_api_key }}"
}

flightaware {
  api_key = "{{ .Data.data.flightaware_api_key }}"
}

poll_interval      = "30s"   # fallback default; both sources set their own
enrichment_refresh = "5h"

redis {
  addr     = "redis.service.consul:6379"
  password = "{{ .Data.data.redis_password }}"
}

squawk_monitor {
  interval = "1000s"
}

postgres {
  dsn = "postgres://{{ .Data.data.db_username }}:{{ .Data.data.db_password }}@haproxy-postgres.service.consul:5433/flight_fetcher?sslmode=require&target_session_attrs=read-write"
}

server {
  listen  = ":8080"
  refresh = 3
}

retention {
  sightings_max_age = "720h"
  alerts_max_age    = "168h"
  routes_max_age    = "24h"
}
{{ end }}
EOH
        destination = "secrets/config.hcl"
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu        = 200
        memory     = 128
        memory_max = 256
      }

      # --- Termination ---
      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
