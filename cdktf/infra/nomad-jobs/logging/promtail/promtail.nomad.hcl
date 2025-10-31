# -------------------------------------------------------------------------------
# Promtail — Nomad System Job for log collection (v3.3.1 FINAL)
# -------------------------------------------------------------------------------

job "promtail" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "system"
  node_pool   = "all"

  meta {
    version     = "3.3.1"
    updated     = "2025-10-31"
    description = "Promtail log collection agent - file-based for containers"
  }

  group "promtail" {
    network {
      mode = "host"
      port "http" {
        static = 9080
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      stagger          = "30s"
    }

    task "promtail" {
      driver = "docker"

      config {
        image        = "grafana/promtail:3.3.1"
        network_mode = "host"
        ports        = ["http"]

        dns_servers        = ["192.168.68.62", "192.168.68.64"]
        dns_search_domains = ["service.consul"]
        dns_options        = ["timeout:2", "attempts:3", "ndots:1"]

        args = [
          "-config.file=/etc/promtail/config.yaml",
        ]

        volumes = [
          "/var/log/journal:/var/log/journal:ro",
          "/run/log/journal:/run/log/journal:ro",
          "/etc/machine-id:/etc/machine-id:ro",
          "local/config:/etc/promtail:ro",
          "/opt/nomad/alloc:/opt/nomad/alloc:ro",
          "/opt/nomad/data/alloc:/opt/nomad/data/alloc:ro",
        ]
      }

      template {
        destination = "local/config/config.yaml"
        change_mode = "restart"
        left_delimiter  = "[["
        right_delimiter = "]]"

        data = <<-YAML
<<INJECT:files/config.yaml>>
        YAML
      }

      env {
        TZ       = "America/Los_Angeles"
        HOSTNAME = "${node.unique.name}"
      }

      resources {
        cpu    = 150
        memory = 128
      }

      service {
        name     = "promtail"
        port     = "http"
        provider = "consul"
        tags     = ["logging", "promtail"]

        check {
          name     = "promtail-ready"
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "3s"
        }
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
