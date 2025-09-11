# -------------------------------------------------------------------------------
# Blackbox Exporter — Nomad Job (internal vantage; port :9115; Consul service)
#
# - Fix: point --config.file to /local/blackbox.yml (where Nomad renders template files)
# - If you want *outside-in*, also run another blackbox_exporter on an external VM
#   and keep Prometheus scraping that one as configured above.
# -------------------------------------------------------------------------------

job "blackbox-exporter" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "blackbox" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "stabler"
    }

    network {
      port "http" { to = 9115 }
    }

    task "exporter" {
      driver = "docker"

      config {
        image = "prom/blackbox-exporter:v0.25.0"
        ports = ["http"]

        # IMPORTANT: Nomad templates land under /local inside the container
        args = ["--config.file=/local/blackbox.yml"]
      }

      template {
        destination   = "local/blackbox.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        perms         = "0644"
        data          = <<-EOT
          modules:
            https_2xx:
              prober: http
              http:
                method: GET
                fail_if_not_ssl: true
                preferred_ip_protocol: "ip4"
                valid_http_versions: ["HTTP/1.1","HTTP/2"]
                tls_config:
                  insecure_skip_verify: false
        EOT
      }

      resources {
        cpu    = 50
        memory = 64
      }

      service {
        name = "blackbox-exporter"
        port = "http"
        tags = ["metrics", "prometheus"]
        check {
          type     = "http"
          path     = "/metrics"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
