###############################################################################
# Prometheus — Nomad Job (with persistent data under /opt/nomad/data)
#
# - Runs Prometheus using the official Docker image
# - Persists all TSDB data on the host at /opt/nomad/data/prometheus
# - Registers with Consul for service discovery
# - Scrapes Nomad, Node Exporter, and itself (edit scrape_configs as needed)
# - Exposes the web UI on port 9090 (can be routed via Traefik)
###############################################################################

# ──────────────────────────────────────────────────────────────────────────────
# 1) Make sure your Nomad client has this in /etc/nomad.d/client.hcl:
#
# client {
#   host_volume "prometheus-data" {
#     path      = "/opt/nomad/data/prometheus"
#     read_only = false
#   }
# }
#
# Then `sudo systemctl restart nomad` on each node.
# ──────────────────────────────────────────────────────────────────────────────

# TODO: 1921.68.1.223 is eth0 on pi5 which is 192.168.1.225 everywhere else becauseit 
# was on wlan0 before I moved it to eth0.  Need to fix this so it works on all nodes.

job "prometheus" {
  datacenters = ["pi-dc"]
  type        = "service"

  meta {
    run_uuid = "${uuidv4()}"
  }

  group "prometheus" {
    count = 1

    # ────────────────────────────────────────────────────────────────
    # Attach the host_volume declared in client.hcl
    # ────────────────────────────────────────────────────────────────
    volume "prometheus-data" {
      type      = "host"
      source    = "prometheus-data"
      read_only = false
    }

    # ────────────────────────────────────────────────────────────────
    # Expose the Prometheus web UI on port 9090 via bridge networking
    # ────────────────────────────────────────────────────────────────
    network {
      port "web" { static = 9090 }
      mode = "bridge"
    }

    # ────────────────────────────────────────────────────────────────
    # Prometheus Task
    # ────────────────────────────────────────────────────────────────
    task "prometheus" {
      driver = "docker"

      service {
        name     = "prometheus"
        port     = "web"
        provider = "consul"

        tags = [
          # Uncomment to enable Traefik routing at http://prometheus.lan
          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.lan`)",
          "traefik.http.routers.prometheus.entrypoints=web",
          "traefik.http.services.prometheus.loadbalancer.server.port=9090"
        ]

        check {
          name     = "prometheus-http"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image              = "prom/prometheus:latest"
        ports              = ["web"]
        image_pull_timeout = "10m"
        args = [
          "--config.file=/etc/prometheus/config/prometheus.yml",
          "--storage.tsdb.path=/prometheus-data",
          "--web.listen-address=0.0.0.0:9090",
          "--web.enable-lifecycle"
        ]

        volumes = [
          "local/config:/etc/prometheus/config",
        ]
      }

      # ────────────────────────────────────────────────────────────────
      # Mount persistent data volume
      # ────────────────────────────────────────────────────────────────
      volume_mount {
        volume      = "prometheus-data"
        destination = "/prometheus-data"
        read_only   = false
      }

      # ────────────────────────────────────────────────────────────────
      # Supply Prometheus config as a Nomad template
      # ────────────────────────────────────────────────────────────────
      template {
        destination = "local/config/prometheus.yml"
        change_mode = "restart"
        perms       = "0644"
        data = <<-EOT
          global:
            scrape_interval: 15s

          scrape_configs:
            - job_name: 'prometheus'
              static_configs:
                - targets: ['localhost:9090']

            - job_name: 'nomad'
              metrics_path: '/v1/metrics'
              params:
                format: [prometheus]
              static_configs:
                - targets: [
                    '192.168.1.225:4646',
                    '192.168.1.115:4646',
                    '192.168.1.222:4646'
                  ]

            - job_name: 'node-exporter'
              params:
                format: [prometheus]
              static_configs:
                - targets: [
                    '192.168.1.223:9100',
                    '192.168.1.222:9100',
                    '192.168.1.115:9100',
                  ]
        EOT
      }

      env = {
        TZ = "America/Los_Angeles"
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

