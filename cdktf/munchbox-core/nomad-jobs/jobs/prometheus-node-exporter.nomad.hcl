# -------------------------------------------------------------------------------
# Prometheus — Node Exporter (Nomad System Job)
#
# PURPOSE:
# - Run node_exporter on every node via a Nomad "system" job.
# - Host networking on static port 9100 per node.
# - Exporter explicitly binds IPv4 to the Nomad-assigned port (== 9100 here).
# - Consul service registration with HTTP health check on /metrics.
# - address_mode=host so Consul probes the node’s LAN IP (not container/bridge).
# - Slightly relaxed health timeouts and check_restart for resilience.
# -------------------------------------------------------------------------------

job "node-exporter-core" {

  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "all"
  type        = "system"

  group "prometheus_node_exporter" {

    # --- Networking -----------------------------------------------------------
    network {
      mode = "host"

      # Static mapping so the exporter is always on 9100 per node.
      port "http" {
        static = 9100
      }
    }

    # --- Task: node_exporter --------------------------------------------------
    task "prometheus_node_exporter" {
      driver = "docker"

      config {
        image = "quay.io/prometheus/node-exporter:v1.8.2"

        # IMPORTANT:
        # - Bind exporter to the exact port Nomad assigned for label "http".
        # - Force IPv4 bind to avoid IPv6-only socket behavior ([::] not accepting IPv4).
        args = [
          "--path.rootfs=/host",
          "--web.listen-address=0.0.0.0:${NOMAD_PORT_http}",
          "--web.telemetry-path=/metrics"
        ]

        # Share host PID namespace to improve visibility for some collectors.
        pid_mode = "host"

        # Mount the host rootfs as read-only under /host for filesystem collectors.
        volumes = [
          "/:/host:ro,rslave",
        ]
      }

      resources {
        cpu    = 50
        memory = 64
      }

      # --- Consul Service Registration ---------------------------------------
      service {
        name         = "prometheus-node-exporter"
        port         = "http"
        tags         = []
        provider     = "consul"
        address_mode = "host"   # Register the node’s IP, not a container/bridge address.

        check {
          name     = "node-exporter-alive"
          type     = "http"
          method   = "GET"
          path     = "/metrics"
          port     = "http"
          interval = "5s"
          timeout  = "3s"
        }
      }
    }
  }
}

