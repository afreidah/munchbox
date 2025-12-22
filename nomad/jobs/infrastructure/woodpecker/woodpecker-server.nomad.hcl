# -------------------------------------------------------------------------------
# Woodpecker Server — CI/CD Pipeline Orchestrator
#
# Project: Munchbox / Author: Alex Freidah
#
# Woodpecker CI server connects to Forgejo via OAuth for repository access and
# webhook events. Manages pipeline execution, stores build history, and provides
# web UI for monitoring. Agents connect to execute actual build workloads.
# -------------------------------------------------------------------------------

job "woodpecker-server" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"

  constraint {
    attribute = "${node.unique.name}"
    value     = "nomad-client-02"
  }

  group "woodpecker-server" {
    count = 1

    network {
      mode = "host"
      port "http" {
        static = 8000
      }
      port "grpc" {
        static = 9000
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    service {
      name     = "woodpecker-server"
      port     = "http"
      provider = "consul"

      tags = [
        "woodpecker",
        "ci",
        "infrastructure",
        "traefik.enable=true",
        "traefik.http.services.woodpecker-server.loadbalancer.server.port=8000",
        # Main UI router - protected by Authentik
        "traefik.http.routers.woodpecker-server.rule=Host(`woodpecker.munchbox.cc`) && !PathPrefix(`/api`) && !PathPrefix(`/hook`) && !PathPrefix(`/authorize`)",
        "traefik.http.routers.woodpecker-server.entrypoints=websecure",
        "traefik.http.routers.woodpecker-server.tls.certresolver=letsencrypt",
        "traefik.http.routers.woodpecker-server.service=woodpecker-server",
        "traefik.http.routers.woodpecker-server.middlewares=authentik@file",
        # API/webhook/OAuth router - no auth
        "traefik.http.routers.woodpecker-api.rule=Host(`woodpecker.munchbox.cc`) && (PathPrefix(`/api`) || PathPrefix(`/hook`) || PathPrefix(`/authorize`))",
        "traefik.http.routers.woodpecker-api.entrypoints=websecure",
        "traefik.http.routers.woodpecker-api.tls.certresolver=letsencrypt",
        "traefik.http.routers.woodpecker-api.service=woodpecker-server",
        # HTTP router for CF tunnel
        "traefik.http.routers.woodpecker-server-http.rule=Host(`woodpecker.munchbox.cc`) && !PathPrefix(`/api`) && !PathPrefix(`/hook`) && !PathPrefix(`/authorize`)",
        "traefik.http.routers.woodpecker-server-http.entrypoints=web",
        "traefik.http.routers.woodpecker-server-http.service=woodpecker-server",
        "traefik.http.routers.woodpecker-server-http.middlewares=cf-tunnel-https@file,authentik@file",
      ]

      check {
        name     = "woodpecker-health"
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "woodpecker-server" {
      driver = "docker"

      vault {
        role = "nomad-workloads"
      }

      config {
        image        = "woodpeckerci/woodpecker-server:v3.12.0"
        ports        = ["http", "grpc"]
        network_mode = "host"
      }

      template {
        data = <<-EOF
        {{ with secret "secret/data/woodpecker" }}
        WOODPECKER_FORGEJO_CLIENT={{ .Data.data.forgejo_client_id }}
        WOODPECKER_FORGEJO_SECRET={{ .Data.data.forgejo_client_secret }}
        WOODPECKER_AGENT_SECRET={{ .Data.data.agent_secret }}
        WOODPECKER_DATABASE_DATASOURCE=postgres://{{ .Data.data.db_username }}:{{ .Data.data.db_password }}@postgres-primary.service.consul:5432/woodpecker?sslmode=disable
        {{ end }}
        EOF
        destination = "secrets/woodpecker.env"
        env         = true
      }

      env {
        WOODPECKER_HOST             = "https://woodpecker.munchbox.cc"
        WOODPECKER_OPEN             = "false"
        WOODPECKER_ADMIN            = "alex"
        WOODPECKER_FORGEJO          = "true"
        WOODPECKER_FORGEJO_URL      = "https://git.munchbox.cc"
        WOODPECKER_DATABASE_DRIVER  = "postgres"
        WOODPECKER_GRPC_ADDR        = "0.0.0.0:9000"
        WOODPECKER_LOG_LEVEL        = "debug"
        TZ                          = "America/Los_Angeles"
        OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.service.consul:4317"
        OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
        OTEL_SERVICE_NAME           = "woodpecker-server"
      }

      resources {
        cpu    = 256
        memory = 256
      }

      kill_timeout = "30s"
    }
  }
}
