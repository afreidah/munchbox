job "prometheus-core" {

  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  namespace   = "default"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  group "prometheus" {

    network {
      mode = "host"
      port "http" {
        to = 9090
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:v2.54.1"
        args  = ""
        volumes = [
          "local/config:/etc/prometheus/config",
        ]
      }
      template {
        data = <<EOH
---
global:
  scrape_interval: 30s
  evaluation_interval: 3s

rule_files:
  - rules.yml

alerting:
 alertmanagers:
    - consul_sd_configs:
      - server: {{ env "attr.unique.network.ip-address" }}:8500
        services:
        - alertmanager

scrape_configs:
  - job_name: prometheus
    static_configs:
    - targets:
      - 0.0.0.0:9090
  - job_name: "nomad_server"
    metrics_path: "/v1/metrics"
    params:
      format:
      - "prometheus"
    consul_sd_configs:
    - server: "{{ env "attr.unique.network.ip-address" }}:8500"
      services:
        - "nomad"
      tags:
        - "http"
  - job_name: "nomad_client"
    metrics_path: "/v1/metrics"
    params:
      format:
      - "prometheus"
    consul_sd_configs:
    - server: "{{ env "attr.unique.network.ip-address" }}:8500"
      services:
        - "nomad-client"

EOH

        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/config/prometheus.yml"
      }

      resources {
        cpu    = 300
        memory = 512
      }
      service {
        name = "prometheus"
        port = "http"
        tags = []

        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "3s"
          timeout  = "1s"
        }
      }
    }
  }
}

