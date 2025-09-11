# -------------------------------------------------------------------------------
# Prometheus — Nomad Job (with persistent data under /opt/nomad/data)
#
# - Single instance on core pool
# - Host networking so Prometheus can reach local Consul agent on stabler
# - TSDB persisted under /opt/nomad/data/prometheus-data
# - Traefik tags preserved for service discovery/routing
# - Scrapes self, Nomad servers, node_exporter (Consul SD), and blackbox
#   (internal via Consul SD + external exporter)
# - /etc/hosts-style entries via Docker extra_hosts for reliable hostname resolution
# - RUNS AS ROOT to avoid host-volume permission issues on /opt/nomad/data/prometheus-data
# - UPDATES:
#   • node_exporter discovery fixed (no bogus 0.0.0.1:2) and fully dynamic via Consul SD
#   • blackbox_internal uses Consul SD; external keeps static exporter
#   • Consul SD server uses env fallback: CONSUL_HTTP_ADDR or 127.0.0.1:8500 (no 'default' func)
#   • Rules file rendered and hot-reloaded with SIGHUP
#   • Nomad scrape uses 127.0.0.1 for stabler (Prometheus host)
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
      port "web" { static = 9090 }
    }

    task "prometheus" {
      driver = "docker"
      user   = "root"   # run as root to avoid TSDB perms issues

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
          "local/config:/etc/prometheus/config"
        ]
      }

      # -------------------------------------------------------------------------
      # Mount persistent data volume for TSDB
      # -------------------------------------------------------------------------
      volume_mount {
        volume      = "prometheus-data"
        destination = "/opt/nomad/data/prometheus-data"
        read_only   = false
      }

      # -------------------------------------------------------------------------
      # Render Prometheus config (dynamic discovery where possible)
      # -------------------------------------------------------------------------
      template {
        destination = "local/config/prometheus.yml"
        change_mode = "restart"  # restart Prometheus on config changes
        perms       = "0644"
        data        = <<-EOT
          global:
            scrape_interval: 15s
            evaluation_interval: 15s

          rule_files:
            - /etc/prometheus/config/alert_rules.yml

          scrape_configs:
            # --- Prometheus self ---
            - job_name: 'prometheus'
              static_configs:
                - targets: ['127.0.0.1:9090']

            # --- Nomad metrics (HTTPS /v1/metrics?format=prometheus)
            #     Use 127.0.0.1 for stabler since Prometheus runs on this host
            - job_name: 'nomad'
              metrics_path: '/v1/metrics'
              params:
                format: [prometheus]
              scheme: https
              tls_config:
                insecure_skip_verify: true
              static_configs:
                - targets:
                    - 'mccoy:4646'
                    - '127.0.0.1:4646'   # stabler (local)
                    - 'cabot:4646'
                    - '192.168.68.60:4646'

            # --- node_exporter via Consul SD (dynamic; no hardcoded hosts) ---
            - job_name: 'node-exporter'
              consul_sd_configs:
                - server: '{{ with env "CONSUL_HTTP_ADDR" }}{{ . }}{{ else }}127.0.0.1:8500{{ end }}'
                  token: '{{ key "prometheus/sd/token" }}'
              relabel_configs:
                # Keep only services that look like node-exporter
                - source_labels: [__meta_consul_service]
                  regex: '.*node[-_]?exporter.*'
                  action: keep
                # Build __address__ = "<service_address>:<service_port>" in one step
                - source_labels: [__meta_consul_service_address, __meta_consul_service_port]
                  separator: ':'
                  target_label: __address__
                  replacement: '${1}:${2}'
                # Optional: present a clean "instance" in UI
                - source_labels: [__address__]
                  target_label: instance

            # --- Blackbox INTERNAL vantage (discover exporter via local Consul) ---
            - job_name: 'blackbox_internal'
              metrics_path: /probe
              params:
                module: ['https_2xx']                     # must exist in blackbox.yml
                target: ['https://resume.alexfreidah.com/']  # URL to probe
              consul_sd_configs:
                - server: '{{ with env "CONSUL_HTTP_ADDR" }}{{ . }}{{ else }}127.0.0.1:8500{{ end }}'
                  token: '{{ key "prometheus/sd/token" }}'
                  services: ['blackbox-exporter']
              relabel_configs:
                # Use the discovered exporter as the scrape address
                - source_labels: [__meta_consul_service_address, __meta_consul_service_port]
                  regex: '(.+);(.+)'
                  target_label: __address__
                  replacement: '${1}:${2}'
                # Show the probed URL as the instance label
                - source_labels: [__param_target]
                  target_label: instance
                # Mark this vantage explicitly
                - target_label: vantage
                  replacement: internal

            # --- Blackbox EXTERNAL vantage (outside-in from remote exporter) ---
            - job_name: 'blackbox_external'
              metrics_path: /probe
              params:
                module: ['https_2xx']                     # ensure external exporter defines this
                target: ['https://resume.alexfreidah.com/']
              static_configs:
                - targets: ['blackbox.example.net:9115']  # remote exporter address:port
                  labels:
                    vantage: "external"
              relabel_configs:
                - source_labels: [__param_target]
                  target_label: instance
        EOT
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
        data            = <<-EOT
          groups:

            # ===========================================================================
            # Nomad MUST-RUN (example retained)
            # ===========================================================================
            - name: nomad-jobs
              rules:
                - alert: NomadJobDown
                  expr: sum by (job, namespace) (nomad_nomad_job_summary_running{job=~"traefik|prometheus|api|web"}) < 1
                  for: 2m
                  labels: { severity: critical, team: ops }
                  annotations:
                    summary: "Nomad job down: {{ $labels.job }} (ns={{ $labels.namespace }})"
                    description: "No running allocations for {{ $labels.job }} for 2 minutes. Check evaluations/allocs in Nomad."
                    runbook: "nomad job status {{ $labels.job }}"

            # ===========================================================================
            # Blackbox — Core Availability / Status / TLS Expiry
            # ===========================================================================
            - name: blackbox-core
              rules:
                - record: probe:duration_seconds:avg5m
                  expr: avg_over_time(probe_duration_seconds[5m])
                  labels: { source: "blackbox" }

                - alert: BlackboxTargetDown
                  expr: probe_success == 0
                  for: 2m
                  labels: { severity: critical, team: web }
                  annotations:
                    summary: "Target DOWN — {{ $labels.instance }} ({{ $labels.vantage }})"
                    description: "Blackbox probe is failing for >2m."

                - alert: BlackboxTargetSlow
                  expr: quantile_over_time(0.95, probe_duration_seconds[10m]) > 1.5
                  for: 10m
                  labels: { severity: warning, team: web }
                  annotations:
                    summary: "High latency (p95 > 1.5s) — {{ $labels.instance }} ({{ $labels.vantage }})"
                    description: "Sustained high latency over the last 10 minutes."

                - alert: BlackboxHTTPBadStatus
                  expr: probe_http_status_code >= 400
                  for: 2m
                  labels: { severity: critical, team: web }
                  annotations:
                    summary: "Bad HTTP status {{ $value }} — {{ $labels.instance }} ({{ $labels.vantage }})"
                    description: "Probe returned HTTP status >= 400 for >2m."

                - alert: BlackboxTLSSoonExpiry
                  expr: (probe_ssl_earliest_cert_expiry - time()) < 21*24*60*60
                  for: 5m
                  labels: { severity: warning, team: web }
                  annotations:
                    summary: "TLS cert expiring soon — {{ $labels.instance }}"
                    description: "Earliest certificate expires within 21 days."

            # ===========================================================================
            # Blackbox — Correlation (compare internal vs external vantage)
            # ===========================================================================
            - name: blackbox-correlation
              rules:
                - alert: BlackboxExternalOnlyDown
                  expr: |
                    (probe_success{vantage="external"} == 0)
                    and on(instance)
                    (probe_success{vantage="internal"} == 1)
                  for: 2m
                  labels: { severity: warning, team: web }
                  annotations:
                    summary: "External-only outage — {{ $labels.instance }}"
                    description: "External vantage failing while internal is healthy. Check DNS, CDN, ISP, geofencing, or perimeter."

                - alert: BlackboxGlobalDown
                  expr: |
                    (probe_success{vantage="external"} == 0)
                    and on(instance)
                    (probe_success{vantage="internal"} == 0)
                  for: 2m
                  labels: { severity: critical, team: web }
                  annotations:
                    summary: "Global outage — {{ $labels.instance }}"
                    description: "Both internal and external vantages failing (origin/app issue likely)."

            # ===========================================================================
            # Blackbox — Phase Diagnostics (pinpoint slow stage)
            # ===========================================================================
            - name: blackbox-phases
              rules:
                - alert: BlackboxDNSSlow
                  expr: avg_over_time(probe_http_duration_seconds{phase="resolve"}[10m]) > 0.5
                  for: 10m
                  labels: { severity: warning, team: web }
                  annotations:
                    summary: "DNS slow — {{ $labels.instance }} ({{ $labels.vantage }})"
                    description: "Average DNS resolution time > 500ms over 10 minutes."

                - alert: BlackboxConnectSlow
                  expr: avg_over_time(probe_http_duration_seconds{phase="connect"}[10m]) > 0.5
                  for: 10m
                  labels: { severity: warning, team: web }
                  annotations:
                    summary: "Connect slow — {{ $labels.instance }} ({{ $labels.vantage }})"
                    description: "Average TCP connect time > 500ms over 10 minutes."

                - alert: BlackboxTLSSlow
                  expr: avg_over_time(probe_http_duration_seconds{phase="tls"}[10m]) > 0.75
                  for: 10m
                  labels: { severity: warning, team: web }
                  annotations:
                    summary: "TLS handshake slow — {{ $labels.instance }} ({{ $labels.vantage }})"
                    description: "Average TLS handshake time > 750ms over 10 minutes."

                - alert: BlackboxTooManyRedirects
                  expr: probe_http_redirects > 5
                  for: 5m
                  labels: { severity: warning, team: web }
                  annotations:
                    summary: "Too many redirects — {{ $labels.instance }} ({{ $labels.vantage }})"
                    description: "Observed > 5 HTTP redirects. Check canonical URL and ingress/LB rules."
        EOT
      }

      # -------------------------------------------------------------------------
      # Environment passed to the Prometheus container
      # - CONSUL_HTTP_TOKEN provides ACL for Consul SD (read-only)
      # - CONSUL_HTTP_ADDR optional; config falls back to 127.0.0.1:8500 if unset
      # -------------------------------------------------------------------------
      env = {
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
