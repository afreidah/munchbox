# -------------------------------------------------------------------------------
#  Hashi-UI — Nomad and Consul Cluster Management Dashboard
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Unified dashboard for Nomad and Consul cluster management. Pulls Nomad ACL
#  token from Vault for secure API access. Connects to Nomad (https) and Consul
#  (http) agents using environment variables. Runs on goren node and exposes
#  web UI on :3000 with Traefik routing to nomad.munchbox (LAN-only).
# -------------------------------------------------------------------------------

job "hashi-ui" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # --- Job metadata ---
  meta {
    version     = "1.3.3"
    owner       = "alex.freidah"
    category    = "infrastructure"
    tier        = "tier-1"
    environment = "production"
    description = "Hashi-UI dashboard for Nomad and Consul management"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  #  Hashi-UI Server Group
  # ---------------------------------------------------------------------------

  group "server" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }

    # --- Network configuration ---
    network {
      mode = "host"
      port "http" {
        static = 3000
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
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
    #  Hashi-UI Dashboard Task
    # -----------------------------------------------------------------------

    task "hashi-ui" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image        = "jippi/hashi-ui"
        network_mode = "host"
        ports        = ["http"]
        volumes = [
          "/opt/nomad/tls/nomad-agent-ca.pem:/etc/ssl/certs/nomad-agent-ca.pem",
        ]
      }

      # --- Nomad ACL token from Vault KV ---
      template {
        destination     = "secrets/nomad.env"
        env             = true
        change_mode     = "restart"
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-EOH
[[ with secret "secret/data/hashiuisecret" ]]
NOMAD_TOKEN=[[ .Data.data.token ]]
[[ end ]]
EOH
      }

      # --- Runtime environment ---
      env {
        NOMAD_ENABLE  = "1"
        NOMAD_ADDR    = "https://mccoy:4646"
        NOMAD_CACERT  = "/etc/ssl/certs/nomad-agent-ca.pem"
        CONSUL_ENABLE = "1"
        CONSUL_ADDR   = "http://mccoy:8500"
        CONSUL_CACERT = "/etc/ssl/certs/nomad-agent-ca.pem"
      }

      # --- Service registration ---
      service {
        name     = "hashi-ui"
        port     = "http"
        provider = "consul"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.nomad.rule=Host(`nomad.munchbox`)",
          "traefik.http.routers.nomad.entrypoints=websecure",
          "traefik.http.routers.nomad.tls=true",
          "traefik.http.routers.nomad.middlewares=dashboard-allowlan@file",
          "traefik.http.services.nomad.loadbalancer.server.port=3000",
          "infrastructure",
          "nomad",
          "consul",
          "monitoring"
        ]

        # --- Web UI health check ---
        check {
          name     = "hashi-ui"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # --- Resource allocation ---
      resources {
        cpu    = 500
        memory = 512
      }

      # --- Termination configuration ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
