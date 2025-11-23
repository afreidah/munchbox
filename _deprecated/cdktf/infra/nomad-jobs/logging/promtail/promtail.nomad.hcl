# -------------------------------------------------------------------------------
#  Promtail — System Log Collection Agent for Loki Integration
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  System job that runs on all nodes collecting container logs from journald
#  and Nomad alloc directories. Sends structured logs to Loki via push API
#  for centralized log aggregation and querying.
# -------------------------------------------------------------------------------

job "promtail" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "system"
  node_pool   = "all"

  # --- Job metadata ---
  meta {
    version     = "3.3.1"
    updated     = "2025-10-31"
    description = "Promtail log collection agent - file-based for containers"
  }

  # --- Job update strategy ---
  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = true
    stagger          = "30s"
  }

  # ---------------------------------------------------------------------------
  #  Promtail Group
  # ---------------------------------------------------------------------------

  group "promtail" {
    # --- Network configuration ---
    network {
      mode = "host"
      port "http" {
        static = 9080
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    # -----------------------------------------------------------------------
    #  Promtail Task
    # -----------------------------------------------------------------------

    task "promtail" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image              = "grafana/promtail:3.3.1"
        network_mode       = "host"
        ports              = ["http"]
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

      # --- Promtail configuration template ---
      template {
        destination     = "local/config/config.yaml"
        change_mode     = "restart"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-YAML
<<INJECT:files/config.yaml>>
YAML
      }

      # --- Runtime environment ---
      env {
        TZ       = "America/Los_Angeles"
        HOSTNAME = "${node.unique.name}"
      }

      # --- Service registration ---
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

      # --- Resource allocation ---
      resources {
        cpu    = 150
        memory = 128
      }

      # --- Termination configuration ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
