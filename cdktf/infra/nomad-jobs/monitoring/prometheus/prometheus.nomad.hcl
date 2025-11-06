# -------------------------------------------------------------------------------
#  Prometheus — Metrics Collection with Alert Rules and Dynamic Discovery
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Collects metrics from all cluster services via Consul DNS discovery with
#  dynamic target registration. Runs HTTPS-only site availability probes,
#  maintains 30-day TSDB retention with WAL compression, and evaluates alert
#  rules for system events. Persistent storage on cabot node.
# -------------------------------------------------------------------------------

job "prometheus" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  # --- Job metadata ---
  meta {
    version     = "2.54.1"
    updated     = "2025-09-28"
    description = "Prometheus metrics collection with alerting"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  #  Prometheus Group
  # ---------------------------------------------------------------------------

  group "prometheus" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "cabot"
    }

    # --- Persistent TSDB storage volume ---
    volume "prometheus-data" {
      type      = "host"
      source    = "prometheus-data"
      read_only = false
    }

    # --- Network configuration ---
    network {
      mode = "host"
      port "web" {
        static = 9090
        to     = 9090
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 5
      interval = "10m"
      delay    = "30s"
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
    #  Prometheus Task
    # -----------------------------------------------------------------------

    task "prometheus" {
      driver = "docker"
      user   = "root"

      # --- Workload identity and Vault integration ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker image configuration ---
      config {
        image              = "prom/prometheus:v2.54.1"
        network_mode       = "host"
        ports              = ["web"]
        image_pull_timeout = "10m"
        extra_hosts = [
          "goren:192.168.68.60",
          "green:192.168.68.62",
          "logan:192.168.68.64",
          "stabler:192.168.68.61",
          "mccoy:192.168.68.63",
          "cabot:192.168.68.59"
        ]
        dns_servers        = ["192.168.68.62", "192.168.68.64"]
        dns_search_domains = ["service.consul"]
        dns_options        = ["timeout:2", "attempts:3", "ndots:1"]
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
        volumes = [
          "local/config:/etc/prometheus/config:ro",
          "local/secrets:/etc/prometheus/secrets:ro"
        ]
      }

      # --- Persistent storage volume mount ---
      volume_mount {
        volume      = "prometheus-data"
        destination = "/opt/nomad/data/prometheus-data"
        read_only   = false
      }

      # --- Service registration ---
      service {
        name     = "prometheus"
        port     = "web"
        provider = "consul"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.munchbox`)",
          "traefik.http.routers.prometheus.entrypoints=websecure",
          "traefik.http.routers.prometheus.tls=true",
          "traefik.http.routers.prometheus.middlewares=dashboard-allowlan@file",
          "traefik.http.services.prometheus.loadbalancer.server.port=9090",
          "traefik.http.services.prometheus.loadbalancer.healthcheck.path=/-/ready",
          "traefik.http.services.prometheus.loadbalancer.healthcheck.interval=30s",
          "traefik.http.services.prometheus.loadbalancer.healthcheck.timeout=5s",
          "monitoring",
          "prometheus",
          "metrics"
        ]

        # --- Prometheus health checks ---
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

      # --- Main Prometheus configuration ---
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

      # --- Alert rules configuration ---
      # HTTPS-only site alerting (job="site_https"), 401/403 ignore for Traefik login-gated pages
      template {
        destination     = "local/config/alert_rules.yml"
        change_mode     = "signal"
        change_signal   = "SIGHUP"
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-YAML
<<INJECT:files/alert_rules.yml>>
YAML
      }

      # --- Consul token from Vault KV ---
      template {
        destination     = "local/secrets/consul_token"
        change_mode     = "restart"
        perms           = "0600"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-EOH
      [[ with secret "kv/data/prometheus" ]][[ .Data.data.consul_token ]][[ end ]]
      EOH
      }

      # --- Vault token from Vault workload identity ---
      template {
        destination     = "local/secrets/vault_token"
        change_mode     = "restart"
        perms           = "0600"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-EOH
      [[ env "VAULT_TOKEN" ]]
      EOH
      }

      # --- Runtime environment ---
      env {
        TZ                              = "America/Los_Angeles"
        CONSUL_HTTP_ADDR                = "127.0.0.1:8500"
        PROMETHEUS_WEB_ENABLE_LIFECYCLE = "true"
        PROMETHEUS_WEB_ENABLE_ADMIN_API = "true"
      }

      # --- Resource allocation ---
      resources {
        cpu    = 500
        memory = 1024
      }

      # --- Termination configuration ---
      kill_timeout   = "60s"
      kill_signal    = "SIGTERM"
      shutdown_delay = "30s"
    }
  }
}
