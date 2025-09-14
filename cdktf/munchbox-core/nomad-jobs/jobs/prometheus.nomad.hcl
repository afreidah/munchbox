# -------------------------------------------------------------------------------
# Prometheus — Nomad Job (with persistent data under /opt/nomad/data)
#
# - Single instance on core pool
# - Host networking so Prometheus can reach local Consul agent on stabler
# - TSDB persisted under /opt/nomad/data/prometheus-data
# - Traefik tags preserved for service discovery/routing
# - Scrapes: self, Nomad servers, node_exporter (Consul SD), and site HTTPS via
#   internal blackbox (one URL probe for https://resume.alexfreidah.com/)
# - /etc/hosts-style entries via Docker extra_hosts for reliable hostname resolution
# - RUNS AS ROOT to avoid host-volume permission issues on /opt/nomad/data/prometheus-data
# - UPDATES:
#   • node_exporter discovery fixed (no bogus addresses) and fully dynamic via Consul SD
#   • blackbox: single internal vantage “is the site up” probe; external removed
#   • Consul SD server uses env fallback: CONSUL_HTTP_ADDR or 127.0.0.1:8500
#   • Rules file rendered and hot-reloaded with SIGHUP
#   • Nomad scrape uses stable hostnames (no 127.0.0.1 for remote agents)
#   • Vault scrape uses bearer_token_file on the mounted data volume
# -------------------------------------------------------------------------------

job "prometheus" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "prometheus" {
    count = 1

    # ---------------------------------------------------------------------------
    # Pin to a specific node
    # ---------------------------------------------------------------------------
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "stabler"
    }

    # ---------------------------------------------------------------------------
    # Attach the host_volume declared in client.hcl for persistent TSDB data
    # ---------------------------------------------------------------------------
    volume "prometheus-data" {
      type      = "host"
      source    = "prometheus-data"
      read_only = false
    }

    # ---------------------------------------------------------------------------
    # Host networking: Prometheus listens on :9090 on the node
    # ---------------------------------------------------------------------------
    network {
      mode = "host"

      port "web" {
        static = 9090
      }
    }

    task "prometheus" {
      driver = "docker"
      user   = "root" # run as root to avoid TSDB perms issues

      # -------------------------------------------------------------------------
      # Register in Consul (Traefik tags kept). Service points at host :9090.
      # -------------------------------------------------------------------------
      service {
        name     = "prometheus"
        port     = "web"
        provider = "consul"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.lan`)",
          "traefik.http.routers.prometheus.entrypoints=web",
          "traefik.http.services.prometheus.loadbalancer.server.port=9090"
        ]

        check {
          name     = "prometheus-ready"
          type     = "http"
          path     = "/-/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image              = "prom/prometheus:v2.54.1"
        ports              = ["web"]
        network_mode       = "host"
        image_pull_timeout = "10m"

        # -----------------------------------------------------------------------
        # Hostname pinning via /etc/hosts-style entries so Prometheus can reach agents
        # -----------------------------------------------------------------------
        extra_hosts = [
          "goren:192.168.68.60",
          "green:192.168.68.62",
          "logan:192.168.68.64",
          "stabler:192.168.68.61",
          "mccoy:192.168.68.63",
          "cabot:192.168.68.59"
        ]

        # IMPORTANT: args must be a LIST (not a string)
        args = [
          "--config.file=/etc/prometheus/config/prometheus.yml",
          "--storage.tsdb.path=/opt/nomad/data/prometheus-data",
          "--web.listen-address=0.0.0.0:9090",
          "--web.enable-lifecycle"
          # Optional: "--storage.tsdb.retention.time=30d",
          # Optional: "--log.level=debug"
        ]

        volumes = [
          "/opt/nomad/secrets/prometheus:/etc/prometheus/secrets:ro",
          "local/config:/etc/prometheus/config"
        ]
      }

      # -------------------------------------------------------------------------
      # Mount persistent data volume for TSDB (and a place to drop vault token)
      # Place your token at: /opt/nomad/data/prometheus-data/bao/token on the host
      # -------------------------------------------------------------------------
      volume_mount {
        volume      = "prometheus-data"
        destination = "/opt/nomad/data/prometheus-data"
        read_only   = false
      }

      # -------------------------------------------------------------------------
      # Render Prometheus config (dynamic discovery where possible)
      # NOTE: Using [[ ... ]] delimiters to avoid conflicts with YAML
      # -------------------------------------------------------------------------
      template {
        destination     = "local/config/prometheus.yml"
        change_mode     = "restart" # restart Prometheus on config changes
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-YAML
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/config/alert_rules.yml

scrape_configs:
  # --- Prometheus self ------------------------------------------------
  - job_name: "prometheus"
    static_configs:
      - targets: ["127.0.0.1:9090"]

  # --- Nomad metrics (HTTPS /v1/metrics?format=prometheus) ------------
  #     Use stable hostnames; avoid 127.0.0.1 except on the local host.
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

  # --- Vault (OpenBao) metrics ---------------------------------------
  - job_name: "vault"
    metrics_path: "/v1/sys/metrics"
    scheme: "https"
    bearer_token_file: "/etc/prometheus/secrets/vault_token"
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: ["mccoy:8200"]
        labels:
          cluster: "vault-cluster-b193d95f"

  # --- Node Exporter (Consul SD, minimal + safe) ----------------------
  #     Prefilter by service name; set instance=Consul node for human-friendly legends.
  - job_name: "node-exporter"
    scrape_interval: 15s
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: '[[ with env "CONSUL_HTTP_ADDR" ]][[ . ]][[ else ]]127.0.0.1:8500[[ end ]]'
        token:  '[[ key "prometheus/sd/token" ]]'
        services: ["prometheus-node-exporter"]
    relabel_configs:
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - source_labels: ["__meta_consul_dc"]
        target_label: "consul_dc"

  # --- Site HTTPS — internal blackbox vantage (simple & reliable) ----
  - job_name: "site_https"
    metrics_path: "/probe"
    params:
      module: ["https_2xx"]
    static_configs:
      - targets:
          - "https://resume.alexfreidah.com/"
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__param_target"
      - source_labels: ["__param_target"]
        target_label: "instance"
      - target_label: "__address__"
        replacement: "127.0.0.1:9115"
      - target_label: "vantage"
        replacement: "internal"
YAML
      }

      # -------------------------------------------------------------------------
      # Render alert rules (hot-reload via SIGHUP; keeps Prometheus running)
      # -------------------------------------------------------------------------
      template {
        destination     = "local/config/alert_rules.yml"
        change_mode     = "signal"
        change_signal   = "SIGHUP"
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-YAML
groups:
- name: nomad-jobs
  rules:
    - alert: NomadJobDown
      expr: |
        (
          sum by (job, namespace) (
            max_over_time(
              nomad_nomad_job_summary_running{namespace!="__internal"}[2m]
            )
          ) > 0
        )
        unless on (job, namespace)
        (
          sum by (job, namespace) (
            nomad_nomad_job_summary_running{namespace!="__internal"}
          ) > 0
        )
      for: 2m
      labels:
        severity: critical
        team: ops
      annotations:
        summary: "Nomad job down: {{ $labels.job }} (ns={{ $labels.namespace }})"
        description: "Job had running allocs within the last 2m but has none now (or disappeared)."

- name: site-uptime
  rules:
    - alert: SiteDown
      expr: probe_success{job="site_https"} == 0
      for: 2m
      labels:
        severity: critical
        team: web
      annotations:
        summary: "SITE DOWN — {{ $labels.instance }} ({{ $labels.vantage }})"
        description: "Blackbox probe failing for >2m."

    - alert: SiteTLSSoonExpiry
      expr: (probe_ssl_earliest_cert_expiry{job="site_https"} - time()) < 21*24*60*60
      for: 5m
      labels:
        severity: warning
        team: web
      annotations:
        summary: "TLS cert expiring soon — {{ $labels.instance }}"
        description: "Earliest certificate expires within 21 days."
YAML
      }

      # -------------------------------------------------------------------------
      # Environment passed to the Prometheus container
      # - CONSUL_HTTP_TOKEN provides ACL for Consul SD (read-only)
      # - CONSUL_HTTP_ADDR optional; config falls back to 127.0.0.1:8500 if unset
      # -------------------------------------------------------------------------
      env {
        TZ = "America/Los_Angeles"
        # CONSUL_HTTP_ADDR  = "127.0.0.1:8500"
        # CONSUL_HTTP_TOKEN = "REDACTED_put_your_consul_token_here"  # or use a file+token_file
      }

      resources {
        cpu    = 250
        memory = 512
      }

      restart {
        attempts = 5
        interval = "10m"
        delay    = "30s"
        mode     = "fail"
      }
    }
  }
}
