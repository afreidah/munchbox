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
  node_pool   = "core"

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
      value     = "stabler"
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

        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "prometheus"
          }
        }
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

      # --- Render Vault token from Consul KV into the alloc (self-contained) ---
      template {
        destination     = "local/secrets/vault_token"
        change_mode     = "restart"
        perms           = "0600"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = "[[ key \"monitoring/prometheus/vault_token\" ]]"
      }

      # --- Main Prometheus configuration --------------------------------------
      template {
        destination     = "local/config/prometheus.yml"
        change_mode     = "restart"
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-YAML
# Prometheus Configuration
# This configuration defines scrape targets and alert routing

global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'munchbox'
    datacenter: 'pi-dc'

# Alert rules file
rule_files:
  - /etc/prometheus/config/alert_rules.yml

# Alerting configuration - send alerts to Alertmanager
alerting:
  alertmanagers:
    - scheme: http
      static_configs:
        - targets: ["127.0.0.1:9093"]

# Scrape configuration - what to monitor
scrape_configs:
  # -----------------------------------------------------------------------
  # Self-monitoring - Prometheus scrapes its own metrics
  # -----------------------------------------------------------------------
  - job_name: "prometheus"
    static_configs:
      - targets: ["127.0.0.1:9090"]
        labels:
          service: "prometheus"

  # -----------------------------------------------------------------------
  # Nomad cluster metrics - HTTPS endpoints with custom certs
  # (Multiple servers are scraped; rules dedupe across servers)
  # -----------------------------------------------------------------------
  - job_name: "nomad"
    metrics_path: "/v1/metrics"
    params:
      format: ["prometheus"]
    scheme: "https"
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets:
          - "mccoy:4646"
          - "stabler:4646"
          - "cabot:4646"
          - "goren:4646"
        labels:
          cluster: "nomad"
          role: "server"

  # -----------------------------------------------------------------------
  # Vault/OpenBao metrics - requires bearer token
  # -----------------------------------------------------------------------
  - job_name: "vault"
    metrics_path: "/v1/sys/metrics"
    params:
      format: ["prometheus"]
    scheme: "https"
    bearer_token_file: "/etc/prometheus/local-secrets/vault_token"
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: ["mccoy:8200"]
        labels:
          cluster: "vault-cluster-b193d95f"
          service: "vault"

  # -----------------------------------------------------------------------
  # Node Exporter - Dynamic discovery via Consul
  # -----------------------------------------------------------------------
  - job_name: "node-exporter"
    scrape_interval: 15s
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: '[[ with env "CONSUL_HTTP_ADDR" ]][[ . ]][[ else ]]127.0.0.1:8500[[ end ]]'
        token: '[[ key "monitoring/prometheus/consul_token" ]]'
        services: ["prometheus-node-exporter"]
        datacenter: "dc1"
    relabel_configs:
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - source_labels: ["__meta_consul_dc"]
        target_label: "consul_dc"
      - source_labels: ["__meta_consul_node_metadata_role"]
        target_label: "node_role"

  # -----------------------------------------------------------------------
  # Consul cluster metrics - leader and followers
  # -----------------------------------------------------------------------
  - job_name: "consul"
    metrics_path: "/v1/agent/metrics"
    params:
      format: ["prometheus"]
      token: ['[[ key "monitoring/prometheus/consul_token" ]]']
    scheme: "http"
    static_configs:
      - targets:
          - "mccoy:8500"
          - "stabler:8500"
          - "cabot:8500"
          - "goren:8500"
        labels:
          cluster: "consul"

  # -----------------------------------------------------------------------
  # Site monitoring via Blackbox Exporter (HTTPS-only targets)
  # -----------------------------------------------------------------------
  - job_name: "site_https"
    metrics_path: "/probe"
    params:
      module: ["https_2xx"]
    static_configs:
      - targets:
          - "https://resume.alexfreidah.com/"   # Public site via Cloudflare
        labels:
          vantage: "internal"
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__param_target"
      - source_labels: ["__param_target"]
        target_label: "instance"
      - target_label: "__address__"
        replacement: "127.0.0.1:9115"           # Blackbox exporter endpoint

  # -----------------------------------------------------------------------
  # Traefik metrics - load balancer stats (Consul SD)
  # -----------------------------------------------------------------------
  - job_name: "traefik"
    scheme: "http"
    consul_sd_configs:
      - server: '[[ with env "CONSUL_HTTP_ADDR" ]][[ . ]][[ else ]]127.0.0.1:8500[[ end ]]'
        token: '[[ key "monitoring/prometheus/consul_token" ]]'
        services: ["traefik"]
        datacenter: "dc1"
    relabel_configs:
      # Force scrape to the Traefik metrics port regardless of service port
      - source_labels: ["__meta_consul_service_address"]
        regex: "(.+)"
        target_label: "__address__"
        replacement: "$1:8081"
      - source_labels: ["__meta_consul_service"]
        target_label: "service"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - source_labels: ["__meta_consul_tags"]
        target_label: "consul_tags"
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
# Prometheus Alert Rules
# These rules are evaluated by Prometheus and fire alerts to Alertmanager

groups:
# -------------------------------------------------------------------------------
# Infrastructure Health Alerts
# -------------------------------------------------------------------------------
- name: infrastructure-health
  interval: 30s
  rules:
    - alert: ServiceDown
      expr: up == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Service {{ $labels.instance }} is down"
        description: "{{ $labels.job }} service on {{ $labels.instance }} has been down for more than 2 minutes."

    - alert: HighCPUUsage
      expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage on {{ $labels.instance }}"
        description: "CPU usage is above 80% for more than 5 minutes on {{ $labels.instance }}."

    - alert: HighMemoryUsage
      expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage on {{ $labels.instance }}"
        description: "Memory usage is above 85% for more than 5 minutes on {{ $labels.instance }}."

    - alert: DiskSpaceLow
      expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 90
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Disk space low on {{ $labels.instance }}"
        description: "Disk usage is above 90% on {{ $labels.instance }} ({{ $labels.mountpoint }})."

# -------------------------------------------------------------------------------
# Nomad Cluster Health
# -------------------------------------------------------------------------------
- name: nomad-health
  interval: 30s
  rules:
    # Less noisy scrape alert: only warn if ALL Nomad targets are down
    - alert: NomadScrapeDown
      expr: min by () (up{job="nomad"}) == 0
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Prometheus cannot scrape any Nomad server"
        description: "All Nomad scrape targets are down or unauthorized."

    - alert: NomadJobRunningShrank
      expr: |
        sum by (job_id) (nomad_nomad_job_status_running)
          <
        sum by (job_id) (max_over_time(nomad_nomad_job_status_running[5m]))
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Nomad job running count decreased: {{ $labels.job_id }}"
        description: "Running allocation count is below recent maximum for {{ $labels.job_id }}."

    # Corrected false-positives: dedupe across servers; fire only for active jobs
    - alert: NomadJobFailed
      expr: |
        (
          max without(instance, __address__) (
            nomad_nomad_job_summary_failed{namespace!="__internal"}
            +
            nomad_nomad_job_summary_lost{namespace!="__internal"}
          )
        ) > 0
        and on (job_id, namespace)
        max by (job_id, namespace) (
          nomad_nomad_job_status_running
          +
          nomad_nomad_job_status_pending
        ) > 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Nomad job has failed allocations: {{ $labels.job_id }}"
        description: "Job {{ $labels.job_id }} in namespace {{ $labels.namespace }} has failed or lost allocations."

    - alert: NomadLeaderElection
      expr: increase(nomad_nomad_leader_leadership_lost_total[5m]) > 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Nomad leader election occurred"
        description: "Nomad cluster experienced a leader election in the last 5 minutes."

# -------------------------------------------------------------------------------
# Site Availability (HTTPS-only)
# -------------------------------------------------------------------------------
- name: site-uptime
  interval: 30s
  rules:
    - alert: SiteDown
      expr: |
        probe_success{job="site_https"} == 0
        and on (instance)
        (
          probe_http_status_code{job="site_https"} != 401
          and probe_http_status_code{job="site_https"} != 403
        )
      for: 2m
      labels:
        severity: critical
        team: web
      annotations:
        summary: "Site is down: {{ $labels.instance }}"
        description: "Site {{ $labels.instance }} has been unreachable for more than 2 minutes (non-auth failure)."

    - alert: SiteTLSCertExpiring
      expr: (probe_ssl_earliest_cert_expiry{job="site_https"} - time()) < 21*24*60*60
      for: 5m
      labels:
        severity: warning
        team: web
      annotations:
        summary: "TLS certificate expiring soon: {{ $labels.instance }}"
        description: "TLS certificate for {{ $labels.instance }} expires within 21 days."

    - alert: SiteSlowResponse
      expr: probe_duration_seconds{job="site_https"} > 5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Slow response time: {{ $labels.instance }}"
        description: "Site {{ $labels.instance }} response time is above 5 seconds."

# -------------------------------------------------------------------------------
# Consul Health
# -------------------------------------------------------------------------------
- name: consul-health
  interval: 30s
  rules:
    - alert: ConsulPeersFailed
      expr: consul_raft_peers < 3
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Consul cluster has lost peers"
        description: "Consul cluster has fewer than 3 peers. Current: {{ $value }}"

    - alert: ConsulLeaderElection
      expr: increase(consul_raft_leader_leadership_lost_total[5m]) > 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Consul leader election occurred"
        description: "Consul cluster experienced a leader election."
YAML
      }

      # Environment variables
      env {
        TZ = "America/Los_Angeles"

        # Consul connection details
        CONSUL_HTTP_ADDR = "127.0.0.1:8500"

        # Optional: Enable Prometheus features
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
