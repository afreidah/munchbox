###############################################################################
# Docker Registry UI — Nomad service job
#
# * Provides a web UI for browsing the Docker registry mirror.
# * Uses the joxit/docker-registry-ui image.
# * Connects to the registry service via Consul DNS.
# * Exposes web UI on port 8086.
###############################################################################

job "registry-ui" {
  datacenters = ["pi-dc"]
  type        = "service" # Service job type

  meta {
    run_uuid = "${uuidv4()}" # Unique run identifier
  }

  update {
    healthy_deadline  = "9m"
    progress_deadline = "10m"
  }

  group "ui" {
    count = 1

    volume "registry-ui" {
      type      = "host"
      source    = "registry-ui-data"
      read_only = false
    }

    # constraint {
    #   attribute = "${node.unique.name}"
    #   operator  = "="
    #   value     = "pi-222"
    # }

    network {
      port "http" {
        static = 8086 # Expose UI on port 8086
      }
    }

    task "ui" {
      driver = "docker" # Use Docker driver

      env {
        REGISTRY_TITLE       = "Home_Registry"                       # UI title
        NGINX_PROXY_PASS_URL = "http://registry.service.consul:5000" # Registry backend URL
        NGINX_LISTEN_PORT    = "http"                                # Listen on http port
      }

      config {
        image               = "joxit/docker-registry-ui:master-debian" # UI Docker image
        image_pull_timeout  = "10m"                             # Timeout for pulling image
        ports               = ["http"]                                 # Expose http port
      }

      service {
        name = "registry-ui" # Service name for Consul
        port = "http"        # Service port
      }

      volume_mount {
        volume      = "registry-ui"
        destination = "/etc/nginx/conf.d/"
        read_only   = false
      }
    }
  }
}
