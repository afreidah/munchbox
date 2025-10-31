# -------------------------------------------------------------------------------
# Prometheus — Nomad Job with Alert Rules & Dynamic Discovery (HTTPS-only alerts)
#
# Changes in this version:
#   • Alerting for site availability now targets ONLY HTTPS probes (job="site_https")
#   • Kept 401/403 ignore in SiteDown alert to handle Traefik login-gated pages
#   • Dropped the site_http scrape job; added Traefik HTTPS /ping to site_https
#   • Kept existing structure, comments, and Traefik tags
# -------------------------------------------------------------------------------

job "prometheus" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  # Job metadata
  meta {
    version     = "2.54.1"
    updated     = "2025-09-28"
    description = "Prometheus metrics collection with alerting"
  }

  group "prometheus" {
    count = 1

    # Pin to specific node for persistent storage
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "cabot"
    }

    # Host volume for persistent TSDB data
    volume "prometheus-data" {
      type      = "host"
      source    = "prometheus-data" # Defined in client.hcl
      read_only = false
    }

    # Network configuration
    network {
      mode = "host"

      port "web" {
        static = 9090 # Standard Prometheus port
        to     = 9090
      }
    }

    # Restart policy - careful with persistent data
    restart {
      attempts = 5
      interval = "10m"
      delay    = "30s"
      mode     = "fail" # Don't restart indefinitely
    }

    # Update strategy - zero downtime not critical for monitoring
    update {
      max_parallel      = 1
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
    }

    task "prometheus" {
      driver = "docker"
      user   = "root" # Required for host volume permissions

      config {
        image              = "prom/prometheus:v2.54.1"
        network_mode       = "host"
        ports              = ["web"]
        image_pull_timeout = "10m"

        # Hostname resolution for cluster nodes
        extra_hosts = [
          "goren:192.168.68.60",
          "green:192.168.68.62",
          "logan:192.168.68.64",
          "stabler:192.168.68.61",
          "mccoy:192.168.68.63",
          "cabot:192.168.68.59"
        ]

        # >>> DNS so *.service.consul resolves inside the container <<<
        # Use LAN resolvers that forward .consul to Consul (green/logan)
        dns_servers        = ["192.168.68.62", "192.168.68.64"]
        dns_search_domains = ["service.consul"]
        dns_options        = ["timeout:2", "attempts:3", "ndots:1"]

        # Prometheus command line arguments
        args = [
          "--config.file=/etc/prometheus/config/prometheus.yml",
          "--storage.tsdb.path=/opt/nomad/data/prometheus-data",
          "--web.listen-address=0.0.0.0:9090",
          "--web.enable-lifecycle",
          "--web.enable-admin-api",
          "--storage.tsdb.retention.time=30d",
          "--storage.tsdb.wal-compression",
          "--web.page-title=Munchbox Prometheus"
        ]

        # Volume mounts
        volumes = [
          # Vault token for metrics scraping (if needed)
          "/opt/nomad/secrets/prometheus:/etc/prometheus/secrets:ro",
          # Local rendered secrets (Vault token from KV)
          "local/secrets:/etc/prometheus/local-secrets:ro",
          # Configuration files (rendered by templates)
          "local/config:/etc/prometheus/config:ro"
        ]
      }

      # Mount persistent storage volume
      volume_mount {
        volume      = "prometheus-data"
        destination = "/opt/nomad/data/prometheus-data"
        read_only   = false
      }

      # Consul service registration with Traefik v3 tags
      service {
        name     = "prometheus"
        port     = "web"
        provider = "consul"

        tags = [
          "traefik.enable=true",

          # Router configuration
          "traefik.http.routers.prometheus.rule=Host(`prometheus.munchbox`)",
          "traefik.http.routers.prometheus.entrypoints=websecure",
          "traefik.http.routers.prometheus.tls=true",

          # Security middleware - reference file provider
          "traefik.http.routers.prometheus.middlewares=dashboard-allowlan@file",

          # Explicit port for Consul discovery
          "traefik.http.services.prometheus.loadbalancer.server.port=9090",

          # Health checks
          "traefik.http.services.prometheus.loadbalancer.healthcheck.path=/-/ready",
          "traefik.http.services.prometheus.loadbalancer.healthcheck.interval=30s",
          "traefik.http.services.prometheus.loadbalancer.healthcheck.timeout=5s",

          # Metadata tags
          "monitoring",
          "prometheus",
          "metrics"
        ]

        # Health checks
        check {
          name     = "prometheus-ready"
          type     = "http"
          path     = "/-/ready"
          interval = "10s"
          timeout  = "3s"
        }

        check {
          name     = "prometheus-healthy"
          type     = "http"
          path     = "/-/healthy"
          interval = "30s"
          timeout  = "5s"
        }
      }

      # Vault integration for secrets
      vault {
        role     = "nomad-workloads"
        policies = ["cdktf-prometheus-read"]
      }

      # --- Render Vault token from Vault into the alloc (self-contained) ---
      template {
        destination     = "local/secrets/vault_token"
        change_mode     = "restart"
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-EOH
<<INJECT:files/vault_token>>
        EOH
      }

      # --- Render Consul token from Vault KV ---
      template {
        destination     = "local/secrets/consul_token"
        change_mode     = "restart"
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-EOH
<<INJECT:files/consul_token>>
        EOH
      }

      # --- Main Prometheus configuration --------------------------------------
      template {
        destination     = "local/config/prometheus.yml"
        change_mode     = "restart"
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-YAML
<<INJECT:files/prometheus.yml>>
        YAML
      }

      # --- Alert rules (HTTPS-only site alerts; keep 401/403 ignore) ----------
      template {
        destination     = "local/config/alert_rules.yml"
        change_mode     = "signal" # Hot reload with SIGHUP
        change_signal   = "SIGHUP"
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-YAML
<<INJECT:files/alert_rules.yml>>
        YAML
      }

      # Environment variables
      env {
        TZ = "America/Los_Angeles"
        CONSUL_HTTP_ADDR = "127.0.0.1:8500"
        PROMETHEUS_WEB_ENABLE_LIFECYCLE = "true"
        PROMETHEUS_WEB_ENABLE_ADMIN_API = "true"
      }

      # Resource allocation - generous for metrics processing
      resources {
        cpu    = 500
        memory = 1024
      }

      # Lifecycle management
      kill_timeout   = "60s"
      kill_signal    = "SIGTERM"
      shutdown_delay = "30s"
    }
  }
}
