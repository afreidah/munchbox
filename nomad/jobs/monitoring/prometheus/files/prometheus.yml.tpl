# Prometheus Configuration
# This configuration defines scrape targets and alert routing

global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: "munchbox"
    datacenter: "pi-dc"

# Storage configuration - accept out-of-order samples from Tempo metrics generator
storage:
  tsdb:
    out_of_order_time_window: 30m

# Alert rules file
rule_files:
  - /etc/prometheus/config/alert_rules.yml

# Alerting configuration - send alerts to Alertmanager via Consul service discovery
alerting:
  alertmanagers:
    - scheme: http
      consul_sd_configs:
        - server: "127.0.0.1:8500"
          services: ["alertmanager"]
          token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
      relabel_configs:
        # Combine service address and port into __address__
        - source_labels:
            [__meta_consul_service_address, __meta_consul_service_port]
          separator: ":"
          target_label: __address__

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
  # Consul - Cluster health and RPC metrics
  # -----------------------------------------------------------------------
  - job_name: "consul"
    metrics_path: "/v1/agent/metrics"
    scheme: "https"
    tls_config:
      ca_file: "/etc/prometheus/certs/ca-chain.crt"
      insecure_skip_verify: true
    params:
      format: ["prometheus"]
    authorization:
      type: "Bearer"
      credentials: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["consul"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_address"]
        target_label: "__address__"
        replacement: "$1:8501"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  # -----------------------------------------------------------------------
  # Nomad servers - Dynamic discovery via Consul
  # -----------------------------------------------------------------------
  - job_name: "nomad"
    metrics_path: "/v1/metrics"
    scheme: "https"
    tls_config:
      ca_file: "/etc/prometheus/certs/ca-chain.crt"
    authorization:
      credentials_file: "/etc/prometheus/secrets/nomad_token"
    params:
      format: ["prometheus"]
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["nomad"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_address"]
        target_label: "__address__"
        replacement: "$1:4646"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - source_labels: ["__meta_consul_dc"]
        target_label: "consul_dc"
      - target_label: "cluster"
        replacement: "nomad"
      - target_label: "role"
        replacement: "server"

  # -----------------------------------------------------------------------
  # Nomad clients - Dynamic discovery via Consul
  # -----------------------------------------------------------------------
  - job_name: "nomad-client"
    metrics_path: "/v1/metrics"
    scheme: "https"
    tls_config:
      ca_file: "/etc/prometheus/certs/ca-chain.crt"
    authorization:
      credentials_file: "/etc/prometheus/secrets/nomad_token"
    params:
      format: ["prometheus"]
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["nomad-client"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_address"]
        target_label: "__address__"
        replacement: "$1:4646"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - source_labels: ["__meta_consul_dc"]
        target_label: "consul_dc"
      - target_label: "cluster"
        replacement: "nomad"
      - target_label: "role"
        replacement: "client"

  # -----------------------------------------------------------------------
  # Vault metrics - Dynamic discovery via Consul
  # -----------------------------------------------------------------------
  - job_name: "vault"
    metrics_path: "/v1/sys/metrics"
    params:
      format: ["prometheus"]
    scheme: "https"
    tls_config:
      ca_file: "/etc/prometheus/certs/ca-chain.crt"
    bearer_token_file: "/etc/prometheus/secrets/vault_token"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["vault"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_address"]
        target_label: "__address__"
        replacement: "$1:8200"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - source_labels: ["__meta_consul_dc"]
        target_label: "consul_dc"
      - target_label: "cluster"
        replacement: "vault"

  # -----------------------------------------------------------------------
  # Node Exporter - now handled by Alloy via prometheus.exporter.unix
  # and remote_write to Prometheus (job_name=node-exporter preserved)
  # -----------------------------------------------------------------------

  # -----------------------------------------------------------------------
  # Cloudflared Tunnel metrics - Consul service discovery
  # -----------------------------------------------------------------------
  - job_name: "cloudflared-tunnel"
    scheme: "http"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["cloudflared-tunnel"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address"]
        regex: "(.+)"
        target_label: "__address__"
        replacement: "$1:2000"
      - source_labels: ["__meta_consul_service_address"]
        regex: ""
        target_label: "__address__"
        replacement: "${__meta_consul_address}:2000"
      - source_labels: ["__meta_consul_service"]
        target_label: "service"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  # -----------------------------------------------------------------------
  # Consul cluster metrics (HTTP endpoint)
  # -----------------------------------------------------------------------
  - job_name: "consul-http"
    metrics_path: "/v1/agent/metrics"
    params:
      format: ["prometheus"]
    scheme: "http"
    authorization:
      credentials_file: "/etc/prometheus/secrets/consul_token"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["consul"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_address"]
        target_label: "__address__"
        replacement: "$1:8500"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - source_labels: ["__meta_consul_dc"]
        target_label: "consul_dc"
      - target_label: "cluster"
        replacement: "consul"

  # -----------------------------------------------------------------------
  # Traefik metrics - Consul service discovery
  # -----------------------------------------------------------------------
  - job_name: "traefik"
    scheme: "http"
    honor_labels: true
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["traefik"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address"]
        regex: "(.+)"
        target_label: "__address__"
        replacement: "$1:8081"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  # -----------------------------------------------------------------------
  # Pi-hole Exporter - Consul service discovery (single nomad job scrapes both nodes)
  # -----------------------------------------------------------------------
  - job_name: "pihole-exporter"
    metrics_path: "/metrics"
    # eko exporter polls both pihole API endpoints synchronously on each
    # /metrics hit; 3-4s typical, occasionally longer when pihole is busy.
    # Defaults (10s timeout / 15s interval) blow up; widen both.
    scrape_interval: 30s
    scrape_timeout: 25s
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["pihole-exporter"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  # -----------------------------------------------------------------------
  # Blackbox Exporters (external + internal) - Consul service discovery
  # -----------------------------------------------------------------------
  - job_name: "blackbox"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["blackbox-exporter-external", "blackbox-exporter-internal"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service"]
        target_label: "job"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  # -----------------------------------------------------------------------
  # PostgreSQL Exporter (Primary) - Database metrics via Consul SD
  # -----------------------------------------------------------------------
  - job_name: "postgres-exporter"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["postgres-exporter"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "database"
        replacement: "postgres-shared"
      - target_label: "role"
        replacement: "primary"

  # -----------------------------------------------------------------------
  # Redis Exporter - Cache metrics via Consul service discovery
  # -----------------------------------------------------------------------
  - job_name: "redis-exporter"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["redis-exporter"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "database"
        replacement: "redis-primary"

  # -----------------------------------------------------------------------
  # Nextcloud Exporter - Cloud storage metrics via Consul service discovery
  # -----------------------------------------------------------------------
  - job_name: "nextcloud-exporter"
    metrics_path: "/metrics"
    scrape_interval: 60s
    scrape_timeout: 30s
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["nextcloud-exporter"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "nextcloud"

  # -----------------------------------------------------------------------
  # Site monitoring via Blackbox Exporter
  # -----------------------------------------------------------------------
  - job_name: "site_https"
    metrics_path: "/probe"
    params:
      module: ["https_2xx"]
    static_configs:
      - targets:
          # External sites
          - "https://alexfreidah.com"
          - "https://resume.alexfreidah.com/"
          - "https://k3s-status.alexfreidah.com/"
          # Public munchbox.cc services (via Cloudflare tunnel, no Authentik)
          - "https://jellyfin.munchbox.cc/web/"
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__param_target"
      - source_labels: ["__param_target"]
        target_label: "instance"
      - target_label: "__address__"
        replacement: "blackbox-exporter-external.service.consul:9115"

  # -----------------------------------------------------------------------
  # Site monitoring (HTTP) — for sites that are public via Cloudflare tunnel
  # but only listen on plain HTTP internally. Pi-hole resolves *.munchbox.cc
  # to goren, so probing the HTTPS URL from inside the cluster hits Traefik
  # on :443 with no matching router and 404s. These targets are probed over
  # HTTP to match the actual internal entrypoint.
  # -----------------------------------------------------------------------
  - job_name: "site_http"
    metrics_path: "/probe"
    params:
      module: ["http_2xx"]
    static_configs:
      - targets:
          - "http://s3-orchestrator.munchbox.cc/"
          - "http://oracle-watchdog.munchbox.cc/"
          - "http://cloudflare-log-collector.munchbox.cc/"
          - "http://g3.munchbox.cc/"
          - "http://nomad-temporal-jobs.munchbox.cc/"
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__param_target"
      - source_labels: ["__param_target"]
        target_label: "instance"
      - target_label: "__address__"
        replacement: "blackbox-exporter-external.service.consul:9115"

  # -----------------------------------------------------------------------
  # Pi-hole probes — internal-only DNS names + LAN traefik VIP.
  # Routed through the internal blackbox so a WireGuard flap doesn't
  # masquerade as a real pihole outage.
  # -----------------------------------------------------------------------
  - job_name: "pihole_probes"
    metrics_path: "/probe"
    params:
      module: ["http_2xx"]
    static_configs:
      - targets:
          - "http://pihole.munchbox.cc/admin/"
          - "http://pihole-green.munchbox.cc/admin/"
          - "http://pihole-logan.munchbox.cc/admin/"
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__param_target"
      - source_labels: ["__param_target"]
        target_label: "instance"
      - target_label: "__address__"
        replacement: "blackbox-exporter-internal.service.consul:9115"

  # -----------------------------------------------------------------------
  # Alertmanager - Self-monitoring for alerting system health
  # -----------------------------------------------------------------------
  - job_name: "alertmanager"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["alertmanager"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  # -----------------------------------------------------------------------
  # Trivy Dashboard - Vulnerability scan metrics
  # -----------------------------------------------------------------------
  - job_name: "trivy-dashboard"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["trivy-dashboard"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "trivy-dashboard"

  # -----------------------------------------------------------------------
  # CoreDNS - DNS load balancer metrics
  # -----------------------------------------------------------------------
  - job_name: "coredns"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["coredns-metrics"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "coredns"

  # -----------------------------------------------------------------------
  # Forgejo - Git repository metrics
  # -----------------------------------------------------------------------
  - job_name: "forgejo"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["forgejo"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "forgejo"

  # -----------------------------------------------------------------------
  # Patroni - PostgreSQL HA cluster metrics (REST API)
  # -----------------------------------------------------------------------
  - job_name: "patroni"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["patroni"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "patroni"

  # -----------------------------------------------------------------------
  # HAProxy - Database failover proxy metrics
  # -----------------------------------------------------------------------
  - job_name: "haproxy"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["haproxy-metrics"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "haproxy"

  # -----------------------------------------------------------------------
  # Vault Cert Manager - Certificate lifecycle metrics
  # -----------------------------------------------------------------------
  - job_name: "vault-cert-manager"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["vault-cert-manager"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "vault-cert-manager"

  # -----------------------------------------------------------------------
  # Oracle Watchdog - Oracle Cloud node health monitoring
  # -----------------------------------------------------------------------
  - job_name: "oracle-watchdog"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["oracle-watchdog-agent"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_address", "__meta_consul_service_port"]
        separator: ":"
        regex: "([^:]+):(.*)"
        replacement: "$1:$2"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "oracle-watchdog"

  # -----------------------------------------------------------------------
  # Oracle Watchdog Monitor - Session heartbeat metrics from Oracle nodes
  # -----------------------------------------------------------------------
  - job_name: "oracle-watchdog-monitor"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["oracle-watchdog"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_address", "__meta_consul_service_port"]
        separator: ":"
        regex: "([^:]+):(.*)"
        replacement: "$1:$2"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "oracle-watchdog-monitor"

  # -----------------------------------------------------------------------
  # Aptly - Debian package repository metrics
  # -----------------------------------------------------------------------
  - job_name: "aptly"
    metrics_path: "/api/metrics"
    basic_auth:
      username: "admin"
      password: "{{ with secret "secret/data/aptly" }}{{ .Data.data.password }}{{ end }}"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["aptly"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "aptly"

  # -----------------------------------------------------------------------
  # Proxmox VE Exporter - Hypervisor metrics (temperature, CPU, memory)
  # -----------------------------------------------------------------------
  - job_name: "pve"
    metrics_path: "/pve"
    static_configs:
      - targets:
          - "192.168.68.59"  # cabot
          - "192.168.68.63"  # mccoy
          - "192.168.68.65"  # fontana
          - "192.168.68.69"  # rubirosa
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__param_target"
      - source_labels: ["__param_target"]
        target_label: "instance"
      - target_label: "__address__"
        replacement: "pve-exporter.service.consul:9221"

  # -----------------------------------------------------------------------
  # Cloudflare Log Collector - Analytics ingestion metrics
  # -----------------------------------------------------------------------
  - job_name: "cloudflare-log-collector"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["cloudflare-log-collector"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "cloudflare-log-collector"

  # -----------------------------------------------------------------------
  # Flight Fetcher - Aircraft tracking service metrics
  # -----------------------------------------------------------------------
  - job_name: "flight-fetcher"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["flight-fetcher"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "flight-fetcher"

  # -----------------------------------------------------------------------
  # S3 Orchestrator - Unified S3 endpoint metrics
  # -----------------------------------------------------------------------
  - job_name: "s3-orchestrator"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        services: ["s3-orchestrator"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - target_label: "service"
        replacement: "s3-orchestrator"
