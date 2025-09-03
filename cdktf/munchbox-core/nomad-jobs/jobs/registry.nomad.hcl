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
      mode = "host"
      port "registry" {
        static = 5000
      }
    }

    # --- Placement: run only on the specified node (goren) ---------------------
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }

    # Update host volume to match your client config
    volume "registry-data" {
      type      = "host"
      source    = "registry-data"
      read_only = false
    }

    task "registry" {
      driver = "docker"

      config {
        image              = "registry:2"
        image_pull_timeout = "10m"
        network_mode       = "host"
        # Use correct volume mount for persistent data
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
  }
}
