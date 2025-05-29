###############################################################################
# Docker Registry Mirror — Nomad service job
#
# * Runs a Docker registry mirror for caching Docker Hub images.
# * Uses the official registry:2 image.
# * Persists cache data on the host.
# * Exposes HTTP API on port 5000.
# * Registers service with Consul for discovery and health checks.
###############################################################################

job "registry" {
  datacenters = ["pi-dc"] # Nomad datacenter(s) to run in
  type        = "service" # Service job type

  meta {
    run_uuid = "${uuidv4()}" # Unique run identifier
  }

  constraint {
    attribute = "${node.class}"
    operator  = "="
    value     = "pi5"
  }

  group "mirror" {
    network {
      mode = "host" # Use host networking for container
      port "registry" {
        static = 5000 # Expose registry on port 5000
      }
    }

    volume "registry-data" {
      type      = "host"
      source    = "registry-data"
      read_only = false
    }

    task "registry" {
      driver = "docker" # Use Docker driver

      config {
        image        = "registry:2" # Official Docker registry image
        image_pull_timeout = "10m"  # Timeout for pulling image
        network_mode = "host"       # Host networking for container
        # No command/args override – default entrypoint is fine
        volumes = [
          "registry-data:/etc/docker/registry", # Persistent cache directory
          "local/config/config.yml:/etc/docker/registry/config.yml" # Registry config
        ]
      }

      env { TZ = "UTC" } # Set timezone

      # Mount persistent cache
      volume_mount {
        volume = "registry-data"
        destination = "/var/lib/registry"
        read_only   = false
      }

      # Registry configuration template
      template {
        destination = "local/config/config.yml"
        change_mode = "restart"
        perms       = "0644"
      
        data = <<EOT
version: 0.1
log:
  level: info

storage:
  filesystem:
    rootdirectory: /var/lib/registry

http:
  addr: :5000          # ← forces the listener to stay on 5000
EOT
      }

      service {
        name     = "docker-mirror" # Service name for Consul
        provider = "consul"        # Register with Consul
        port     = "registry"      # Service port

        check {
          name         = "http-registry" # Health check name
          type         = "http"          # HTTP health check
          path         = "/v2/"          # Path to check
          interval     = "10s"           # Check interval
          timeout      = "3s"            # Timeout for check
        }
      }
    }
  }
}
