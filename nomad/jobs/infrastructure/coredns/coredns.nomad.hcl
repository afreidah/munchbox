# -------------------------------------------------------------------------------
# CoreDNS — DNS Load Balancer
#
# Project: Munchbox / Author: Alex Freidah
#
# Lightweight DNS forwarder that load balances queries across both Pi-hole
# servers (green and logan). Runs as a system job on every node so each node
# has local DNS with round-robin distribution, health checks, and caching.
#
# Each node's dnsmasq points to localhost:5354 for non-Consul queries.
# -------------------------------------------------------------------------------

# --- Shared Variables (from shared.vars.hcl) ---
variable "pihole_1" {
  type    = string
  default = "192.168.68.62"
}
variable "pihole_2" {
  type    = string
  default = "192.168.68.64"
}

variable "cloudflare" {
  type    = string
  default = "1.1.1.1"
}
variable "google" {
  type    = string
  default = "8.8.8.8"
}

job "coredns" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "system"
  node_pool   = "all"
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
    max_parallel = 1
    stagger      = "30s"
  }

  # ---------------------------------------------------------------------------
  # Task Group: coredns
  # ---------------------------------------------------------------------------

  group "coredns" {

    # --- Network Configuration ---
    network {
      mode = "host"
      port "dns" {
        static = 5354
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
        on_update = "require_healthy"
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
        on_update = "require_healthy"
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
# Forwards to pihole_1 and pihole_2 with round-robin and health checks

.:5354 {
    # Health endpoint on 8053 (avoid 8080 conflicts)
    health :8053 {
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
    forward . ${var.pihole_1} ${var.pihole_2} {
        policy round_robin
        health_check 10s
        max_fails 3
    }

    # Error logging
    errors

    # Query logging (comment out if too verbose)
    # log
}

# Forward .consul queries to local Consul agent DNS
# Prevents .consul lookups (e.g. from trace plugin) from leaking to Pi-holes
consul:5354 {
    forward . 127.0.0.1:8600
    cache 30
    errors
}
EOH
      }

      # --- Resources ---
      # CPU bumped from 100 to 300 MHz: 7d p95 was 179 MHz with bursts to
      # 2.2 GHz under DNS load (system job, runs everywhere — small per-node
      # increase but matters for query latency under load).
      resources {
        cpu    = 300
        memory = 64
      }

      # --- Termination ---
      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
