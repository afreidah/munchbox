# ------------------------------------------------------------------------------
# Grafana — Nomad Job (Traefik under /grafana on *.munchbox)
#
# - Single instance on edge pool (adjust as needed)
# - Host networking so Grafana can reach Prometheus at 127.0.0.1:9090
# - Persistent data under /opt/nomad/data/grafana-data (host volume)
# - Traefik: HostRegexp(`{subdomain:[a-z0-9-]+}.munchbox`) + PathPrefix(`/grafana`)
# - Strip /grafana before proxying; Grafana configured for sub-path
# - Admin password set via env template (demo: 'admin')
# ------------------------------------------------------------------------------

job "grafana" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "edge"

  group "grafana" {
    count = 1

    # --- Placement ---------------------------------------------------------------
    constraint {
      attribute = "${node.class}"
      operator  = "="
      value     = "utility"
    }

    # --- Persistence: host volume ------------------------------------------------
    volume "grafana-data" {
      type      = "host"
      source    = "grafana-data"
      read_only = false
    }

    # --- Networking: host mode, :3000 --------------------------------------------
    network {
      mode = "host"
      port "web" { static = 3000 }
    }

    task "grafana" {
      driver = "docker"

      # --- Service registration (Consul + Traefik tags) --------------------------
      service {
        name     = "grafana"
        port     = "web"
        provider = "consul"

        check {
          name     = "grafana-alive"
          type     = "http"
          path     = "/api/health"
          port     = "web"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # --- Container config -------------------------------------------------------
      config {
        image              = "grafana/grafana:10.4.2"
        ports              = ["web"]
        image_pull_timeout = "10m"
        volumes = [
          "local/grafana-provisioning:/etc/grafana/provisioning"
        ]
      }

      # --- Persistent data mount --------------------------------------------------
      volume_mount {
        volume      = "grafana-data"
        destination = "/opt/nomad/data/grafana-data"
        read_only   = false
      }

      # --- Admin credentials (demo only) -----------------------------------------
      template {
        destination = "secrets/grafana.env"
        env         = true
        data = <<EOH
GF_SECURITY_ADMIN_PASSWORD=admin
EOH
      }

      # --- Grafana env: sub-path operation at /grafana ----------------------------
      # Use a RELATIVE root_url so direct :3000 testing and proxied /grafana both work.
      env = {
        GF_SERVER_SERVE_FROM_SUB_PATH = "false"
        GF_SERVER_ROOT_URL            = "http://grafana.munchbox/"
      }

      resources {
        cpu    = 250
        memory = 512
      }

      restart {
        attempts = 5
        interval = "10m"
        delay    = "30s"
        mode     = "fail"
      }
    }
  }
}
