# -------------------------------------------------------------------------------
# Prometheus — Nomad Job (with persistent data under /opt/nomad/data)
#
# - Single instance on core pool
# - Host networking so Prometheus can reach Consul on 127.0.0.1:8500
# - TSDB persisted under /opt/nomad/data/prometheus-data
# - Traefik tags preserved for service discovery/routing
# - Scrapes self, Nomad servers, and node_exporter (via Consul SD)
# - Mounts host's /etc/hosts for reliable hostname resolution
# -------------------------------------------------------------------------------

job "prometheus" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "prometheus" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }

    # ---------------------------------------------------------------------------
    # Attach the host_volume declared in client.hcl for persistent TSDB data
    # ---------------------------------------------------------------------------
    volume "prometheus-data" {
      type      = "host"
      source    = "prometheus-data"
      read_only = false
    }

    # ---------------------------------------------------------------------------
    # Host networking: Prometheus listens on :9090 on the node; can reach 127.0.0.1:8500
    # Define a labeled port so service/checks can reference it cleanly.
    # ---------------------------------------------------------------------------
    network {
      mode = "host"
      port "web" { static = 9090 }
    }

    task "prometheus" {
      driver = "docker"

      # -------------------------------------------------------------------------
      # Register in Consul (Traefik tags kept). Service points at host :9090.
      # -------------------------------------------------------------------------
      service {
        name     = "prometheus"
        port     = "web"
        provider = "consul"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.lan`)",
          "traefik.http.routers.prometheus.entrypoints=web",
          "traefik.http.services.prometheus.loadbalancer.server.port=9090"
        ]

        check {
          name     = "prometheus-ready"
          type     = "http"
          path     = "/-/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image              = "prom/prometheus:v2.54.1"     # Pin a stable version
        ports              = ["web"]
        image_pull_timeout = "10m"
        extra_hosts = [
          "goren:192.168.68.60",
          "green:192.168.68.62",
          "logan:192.168.68.64",
          "stabler:192.168.68.61",
          "mccoy:192.168.68.63",
          "cabot:192.168.68.59"
        ]

        # IMPORTANT: args must be a LIST (not a string)
        args = [
          "--config.file=/etc/prometheus/config/prometheus.yml",
          "--storage.tsdb.path=/opt/nomad/data/prometheus-data",
          "--web.listen-address=0.0.0.0:9090",
          "--web.enable-lifecycle"
        ]

        volumes = [
          "local/config:/etc/prometheus/config",
        ]
      }

      # -------------------------------------------------------------------------
      # Mount persistent data volume for TSDB
      # -------------------------------------------------------------------------
      volume_mount {
        volume      = "prometheus-data"
        destination = "/opt/nomad/data/prometheus-data"
        read_only   = false
      }

      # -------------------------------------------------------------------------
      # Render Prometheus config: scrape self, Nomad servers, node_exporter via Consul SD
      # -------------------------------------------------------------------------
      template {
        destination = "local/config/prometheus.yml"
        change_mode = "restart"
        perms       = "0644"
        data = <<-EOT
          global:
            scrape_interval: 15s
            evaluation_interval: 15s

          scrape_configs:
            # --- Prometheus self ---
            - job_name: 'prometheus'
              static_configs:
                - targets: ['127.0.0.1:9090']

            # --- Nomad metrics (HTTPS /v1/metrics?format=prometheus) ---
            - job_name: 'nomad'
              metrics_path: '/v1/metrics'
              params:
                format: [prometheus]
              scheme: https
              tls_config:
                insecure_skip_verify: true
              static_configs:
                - targets:
                    - 'mccoy:4646'
                    - 'stabler:4646'
                    - 'cabot:4646'
                    - '192.168.68.60:4646'

            # --- node_exporter via Consul Service Discovery ---
            - job_name: 'node-exporter'
              consul_sd_configs:
                - server: 'http://127.0.0.1:8500'
              relabel_configs:
                # Keep services whose names look like node-exporter (covers 'node-exporter' & 'prometheus-node-exporter')
                - source_labels: [__meta_consul_service]
                  regex: '.*node[-_]?exporter.*'
                  action: keep
                # Use service address + port advertised by Consul
                - source_labels: [__meta_consul_service_address]
                  target_label: __address__
                - source_labels: [__meta_consul_service_port]
                  target_label: __meta_port
                - source_labels: [__address__, __meta_port]
                  regex: '([^;]+);(.*)'
                  replacement: '${1}:${2}'
                  target_label: __address__
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
