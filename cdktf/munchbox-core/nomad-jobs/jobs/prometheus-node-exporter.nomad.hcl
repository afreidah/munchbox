job "node-exporter-core" {

  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "all"
  type        = "system"

  group "prometheus_node_exporter" {

    network {
      mode = "host"
      port "http" {
        static = 19100
      }
    }

    task "prometheus_node_exporter" {
      driver = "docker"

      config {
        image    = "quay.io/prometheus/node-exporter:v1.8.2"
        args     = ["--path.rootfs=/host"]
        pid_mode = "host"

        volumes = [
          "/:/host:ro,rslave",
        ]
      }

      resources {
        cpu    = 50
        memory = 64
      }

      service {
        name     = "prometheus-node-exporter"
        port     = "http"
        tags     = []
        provider = "consul"
        check {
          name     = "node-exporter-alive"
          type     = "http"
          path     = "/metrics"
          port     = "http"
          interval = "3s"
          timeout  = "1s"
        }
      }
    }
  }
}

