###############################################################################
# Docker Registry UI — Nomad service job
#
# * Provides a web UI for browsing the Docker registry mirror.
# * Uses the joxit/docker-registry-ui image.
# * Connects to the registry service via Consul DNS.
# * Exposes web UI on port 8086.
###############################################################################

job "registry-ui" {
  datacenters = ["pi-dc"] # Nomad datacenter(s) to run in
  type        = "service" # Service job type

  meta {
    run_uuid = "${uuidv4()}" # Unique run identifier
  }

  group "ui" {
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
        image       = "joxit/docker-registry-ui:master-debian" # UI Docker image
        image_pull_timeout = "10m"                             # Timeout for pulling image
        ports       = ["http"]                                 # Expose http port
      }

      service {
        name = "registry-ui" # Service name for Consul
        port = "http"        # Service port
      }
    }
  }
}
