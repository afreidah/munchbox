# -------------------------------------------------------------------------------
# CoreDNS — DNS Load Balancer
#
# Project: Munchbox / Author: Alex Freidah
#
# Lightweight DNS forwarder that load balances queries across both Pi-hole
# servers (green and logan). Provides round-robin distribution, health checks,
# automatic failover, and response caching to reduce Pi-hole load.
# -------------------------------------------------------------------------------

job "coredns" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  priority    = 80

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Placement — Pin to stabler (ingress node)
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "nomad-client-03"
  }

  # ---------------------------------------------------------------------------
  # Task Group: coredns
  # ---------------------------------------------------------------------------

  group "coredns" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "dns" {
        static = 5353
      }
      port "metrics" {
        static = 9153
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "1h"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "10m"
      unlimited      = false
    }

    # --- Service Registration ---
    service {
      name     = "coredns"
      port     = "dns"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "dns",
        "load-balancer"
      ]

      check {
        name     = "coredns-dns"
        type     = "tcp"
        port     = "dns"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # --- Metrics Service ---
    service {
      name     = "coredns-metrics"
      port     = "metrics"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "metrics"
      ]

      check {
        name     = "coredns-metrics"
        type     = "http"
        path     = "/metrics"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: coredns
    # -------------------------------------------------------------------------

    task "coredns" {
      driver = "docker"

      # --- Docker Configuration ---
      config {
        image        = "coredns/coredns:1.13.2"
        network_mode = "host"
        args         = ["-conf", "/etc/coredns/Corefile"]
        volumes      = [
          "local/Corefile:/etc/coredns/Corefile:ro"
        ]
      }

      # --- Corefile Configuration ---
      template {
        destination = "local/Corefile"
        change_mode = "restart"
        data        = <<EOH
# CoreDNS Configuration - DNS Load Balancer for Pi-holes
# Forwards to green (192.168.68.62) and logan (192.168.68.64)

.:5353 {
    # Health checks for upstream Pi-holes
    health {
        lameduck 5s
    }

    # Prometheus metrics on :9153
    prometheus 0.0.0.0:9153

    # Tracing to Tempo (via Zipkin endpoint)
    trace tempo.service.consul:9411 {
        every 100
        client_server
    }

    # Cache responses (5 min success, 1 min negative)
    cache 300 {
        success 9984 300
        denial 9984 60
    }

    # Forward to both Pi-holes with health checks
    forward . 192.168.68.62 192.168.68.64 {
        policy round_robin
        health_check 10s
        max_fails 3
    }

    # Error logging
    errors

    # Query logging (comment out if too verbose)
    # log
}
EOH
      }

      # --- Resources ---
      resources {
        cpu    = 100
        memory = 64
      }

      # --- Termination ---
      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
