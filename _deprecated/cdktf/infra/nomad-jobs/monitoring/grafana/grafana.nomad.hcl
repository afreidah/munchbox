# -------------------------------------------------------------------------------
#  Grafana — Monitoring Dashboards and Visualization Service
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Provides Grafana dashboards with Prometheus and Loki datasource integration
#  via Consul DNS. Uses Vault workload identity for JWT auth, provisioned
#  datasources authoritative to prevent drift, and Traefik HTTPS routing to
#  https://grafana.munchbox. Includes prestart permissions fix task.
# -------------------------------------------------------------------------------

job "grafana" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "edge"

  # --- Job metadata ---
  meta {
    version     = "1.0.1"
    owner       = "alex.freidah"
    category    = "monitoring"
    tier        = "tier-1"
    environment = "production"
    description = "grafana service with Promtail/Loki observability additions"
  }

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
  #  Grafana Group
  # ---------------------------------------------------------------------------

  group "grafana" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.class}"
      operator  = "="
      value     = "utility"
    }

    # --- Persistent volume ---
    volume "grafana-data" {
      type      = "host"
      source    = "grafana-data"
      read_only = false
    }

    # --- Network configuration ---
    network {
      mode = "host"
      port "web" {
        static = 3000
        to     = 3000
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
    #  Permissions Prestart Task
    # -----------------------------------------------------------------------

    task "fix-perms" {
      driver = "docker"
      lifecycle {
        hook = "prestart"
      }

      # --- Docker image configuration ---
      config {
        image   = "alpine:3.20"
        command = "sh"
        args = [
          "-c",
          "mkdir -p /var/lib/grafana && chown -R 472:472 /var/lib/grafana && ls -ld /var/lib/grafana"
        ]
      }

      # --- Volume mount ---
      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
        read_only   = false
      }

      # --- Resource allocation ---
      resources {
        cpu    = 50
        memory = 64
      }
    }

    # -----------------------------------------------------------------------
    #  Grafana Task
    # -----------------------------------------------------------------------

    task "grafana" {
      driver = "docker"

      # --- Workload identity and secrets ---
      vault {
        role = "nomad-grafana"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker image configuration ---
      config {
        image              = "grafana/grafana:12.2.0"
        ports              = ["web"]
        image_pull_timeout = "10m"
        network_mode       = "host"
        dns_servers        = ["192.168.68.62", "192.168.68.64"]
        dns_search_domains = ["service.consul"]
        dns_options        = ["timeout:2", "attempts:3", "ndots:1"]
        volumes = [
          "local/grafana-provisioning:/etc/grafana/provisioning"
        ]
      }

      # --- Volume mount ---
      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
        read_only   = false
      }

      # --- Service registration ---
      service {
        name     = "grafana"
        port     = "web"
        provider = "consul"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=Host(`grafana.munchbox`)",
          "traefik.http.routers.grafana.entrypoints=websecure",
          "traefik.http.routers.grafana.tls=true",
          "traefik.http.routers.grafana.middlewares=dashboard-allowlan@file",
          "traefik.http.services.grafana.loadbalancer.server.port=3000",
          "monitoring",
          "grafana"
        ]
        check {
          name     = "grafana-alive"
          type     = "http"
          path     = "/api/health"
          port     = "web"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # --- Vault token debugging template ---
      template {
        destination = "secrets/_debug_policies.txt"
        perms       = "0600"
        data        = "{{ with secret \"auth/token/lookup-self\" }}{{ .Data.policies }}{{ end }}"
      }

      # --- Runtime environment configuration ---
      template {
        destination = "secrets/grafana.env"
        env         = true
        data        = <<EOH
<<INJECT:files/grafana.env>>
EOH
      }

      env {
        GF_SERVER_SERVE_FROM_SUB_PATH = "false"
        GF_SERVER_ROOT_URL            = "https://grafana.munchbox/"
        NO_PROXY                      = "localhost,127.0.0.1,*.service.consul,service.consul,192.168.68.0/24"
      }

      # --- Provisioned datasources configuration ---
      template {
        destination = "local/grafana-provisioning/datasources/ds.yml"
        perms       = "0644"
        data        = <<YAML
<<INJECT:files/ds.yml>>
YAML
      }

      # --- Resource allocation ---
      resources {
        cpu    = 250
        memory = 512
      }

      # --- Task restart behavior ---
      restart {
        attempts = 5
        interval = "10m"
        delay    = "30s"
        mode     = "fail"
      }
    }
  }
}
