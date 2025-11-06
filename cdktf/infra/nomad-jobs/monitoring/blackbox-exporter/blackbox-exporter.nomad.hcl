# -------------------------------------------------------------------------------
#  Blackbox Exporter — Internal Endpoint Monitoring and Metrics Collection
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Runs blackbox exporter on static host port 9115 with host networking for
#  Prometheus probe execution. Uses Consul service registration with LAN IP
#  binding. Probes internal services and endpoints, rendering configuration
#  from Nomad-templated YAML files.
# -------------------------------------------------------------------------------

job "blackbox-exporter" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
  }

  # ---------------------------------------------------------------------------
  #  Blackbox Group
  # ---------------------------------------------------------------------------

  group "blackbox" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "cabot"
    }

    # --- Network configuration ---
    network {
      mode = "host"
      port "http" {
        static = 9115
      }
    }

    # --- Reschedule policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # -----------------------------------------------------------------------
    #  Blackbox Exporter Task
    # -----------------------------------------------------------------------

    task "exporter" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image        = "prom/blackbox-exporter:v0.25.0"
        ports        = ["http"]
        network_mode = "host"
        args         = ["--config.file=/local/blackbox.yml"]
      }

      # --- Blackbox configuration template ---
      template {
        destination   = "local/blackbox.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        perms         = "0644"
        data          = <<-EOT
<<INJECT:files/blackbox.yml>>
EOT
      }

      # --- Task restart behavior ---
      restart {
        attempts = 5
        interval = "10m"
        delay    = "5s"
        mode     = "delay"
      }

      # --- Service registration ---
      service {
        name         = "blackbox-exporter"
        port         = "http"
        provider     = "consul"
        address_mode = "host"
        tags = [
          "metrics",
          "prometheus"
        ]
        check {
          type     = "http"
          path     = "/metrics"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # --- Resource allocation ---
      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
