# -------------------------------------------------------------------------------
# Blackbox Exporter — Nomad Job (internal vantage; host :9115; Consul service)
#
# CHANGES:
# - Force host networking at group + Docker layer (reachable by Prometheus).
# - Static host port 9115 (no ephemeral host port mapping).
# - Consul service registration uses address_mode=host for LAN IP.
# - Config path remains /local/blackbox.yml (Nomad template dir).
# -------------------------------------------------------------------------------

job "blackbox-exporter" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  group "blackbox" {
    count = 1

    # Pin to stabler
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "cabot"
    }

    # --- Networking -----------------------------------------------------------
    network {
      mode = "host"
      port "http" { static = 9115 } # exporter listens on host:9115
    }

    task "exporter" {
      driver = "docker"

      config {
        image        = "prom/blackbox-exporter:v0.25.0"
        ports        = ["http"]
        network_mode = "host"
        args         = ["--config.file=/local/blackbox.yml"]

        # Optional: map domain to internal IP if your router can't hairpin NAT
        # extra_hosts = ["resume.alexfreidah.com:192.168.68.61"]
      }

      # Blackbox modules config rendered by Nomad
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
                valid_http_versions: ["HTTP/1.1","HTTP/2.0"]   # ← key fix
                tls_config:
                  insecure_skip_verify: false
                # headers:
                #   User-Agent: "Mozilla/5.0"
                #   Accept: "*/*"
        EOT
      }

      resources {
        cpu    = 50
        memory = 64
      }

      restart {
        attempts = 5
        interval = "10m"
        delay    = "5s"
        mode     = "delay"
      }

      # --- Consul Service Registration ---------------------------------------
      service {
        name         = "blackbox-exporter"
        port         = "http"
        tags         = ["metrics", "prometheus"]
        provider     = "consul"
        address_mode = "host" # register the node’s LAN IP + 9115

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
