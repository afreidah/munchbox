# -------------------------------------------------------------------------------
# Docker Registry Mirror — Nomad service job
#
# - Runs a Docker registry mirror for caching Docker Hub images.
# - Uses the official registry:2 image.
# - Persists cache data on the host.
# - Exposes HTTP API on port 5000.
# - Registers service with Consul for discovery and health checks.
# -------------------------------------------------------------------------------
job "registry" {
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"
  group "mirror" {
    network {
      port "registry" {
        static = 5000
      }
      port "ui" {
        static = 5001
        to     = 80
      }
    }
    # --- Placement: run only on the specified node (goren) ---------------------
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }
    # Update host volume to match client config
    volume "registry-data" {
      type      = "host"
      source    = "registry-data"
      read_only = false
    }
    # Volume for registry authentication
    volume "registry-auth" {
      type      = "host"
      source    = "registry-auth"
      read_only = true
    }
    task "registry" {
      driver = "docker"
      config {
        image              = "registry:2"
        image_pull_timeout = "10m"
        network_mode       = "host"
        volumes = [
          "local/config/config.yml:/etc/docker/registry/config.yml"
        ]
      }

      env {
        TZ = "UTC"
      }

      volume_mount {
        volume      = "registry-data"
        destination = "/var/lib/registry"
        read_only   = false
      }

      volume_mount {
        volume      = "registry-auth"
        destination = "/auth"
        read_only   = true
      }

      template {
        destination = "local/config/config.yml"
        change_mode = "restart"
        perms       = "0644"
        data        = <<EOT
version: 0.1
log:
  level: info
storage:
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    Access-Control-Allow-Origin: ["http://192.168.68.60:5001", "http://registry.munchbox"]
    Access-Control-Allow-Methods: ["GET", "HEAD", "OPTIONS"]
    Access-Control-Allow-Headers: ["Authorization", "Accept", "Cache-Control", "Content-Type", "Origin"]
EOT
      }

      service {
        name     = "docker-mirror"
        provider = "consul"
        port     = "registry"

        check {
          name     = "http-registry"
          type     = "http"
          path     = "/v2/"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }

    task "registry-ui" {
      driver = "docker"

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      vault {
        role = "nomad-workloads"
      }

      config {
        image = "joxit/docker-registry-ui:latest"
        ports = ["ui"]
      }

      template {
        data        = <<EOH
{{ with secret "kv/data/docker-registry" }}
REGISTRY_PASSWORD="{{ .Data.data.password }}"
{{ end }}
EOH
        destination = "secrets/registry.env"
        env         = true
      }

      env {
        REGISTRY_URL        = "http://goren:5000"
        REGISTRY_TITLE      = "Docker Registry Mirror"
        DELETE_IMAGES       = "false"
        PORT                = "5001"
        REGISTRY_BASIC_AUTH = "true"
        REGISTRY_USERNAME   = "alex.freidah"
      }

      service {
        name     = "docker-registry-ui"
        provider = "consul"
        port     = "ui"
        tags = [
          "traefik.enable=true",

          # Router configuration
          "traefik.http.routers.docker-registry-ui.rule=Host(`registry.munchbox`)",
          "traefik.http.routers.docker-registry-ui.entrypoints=websecure",
          "traefik.http.routers.docker-registry-ui.tls=true",

          # Restrict to LAN (middleware defined in Traefik file provider)
          "traefik.http.routers.docker-registry-ui.middlewares=dashboard-allowlan@file",

          # Explicit backend port
          "traefik.http.services.docker-registry-ui.loadbalancer.server.port=5001",

          # Metadata tags
          "docker",
          "registry",
          "ui",
        ]

        check {
          name                   = "http-registry-ui"
          type                   = "http"
          path                   = "/"
          interval               = "15s"
          timeout                = "5s"
          success_before_passing = 1
        }
      }
    }
  }
}
