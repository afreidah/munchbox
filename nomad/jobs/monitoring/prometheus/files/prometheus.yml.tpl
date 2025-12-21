# Prometheus Configuration
# This configuration defines scrape targets and alert routing

global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: "munchbox"
    datacenter: "pi-dc"

# Alert rules file
rule_files:
  - /etc/prometheus/config/alert_rules.yml

# Alerting configuration - send alerts to Alertmanager via Consul service discovery
alerting:
  alertmanagers:
    - scheme: http
      consul_sd_configs:
        - server: "192.168.68.61:8500"
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
      - server: "192.168.68.61:8500"
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
      - server: "192.168.68.61:8500"
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
      - server: "192.168.68.61:8500"
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
  # Node Exporter - Dynamic discovery via Consul
  # -----------------------------------------------------------------------
  - job_name: "node-exporter"
    scrape_interval: 15s
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "192.168.68.61:8500"
        scheme: "http"
        services: ["node-exporter"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      # First, set address from node address (fallback)
      - source_labels: ["__meta_consul_address", "__meta_consul_service_port"]
        separator: ":"
        target_label: "__address__"
      # Override with service address if it exists (non-empty)
      - source_labels:
          ["__meta_consul_service_address", "__meta_consul_service_port"]
        separator: ":"
        regex: "([^:]+):(.*)"
        replacement: "$1:$2"
        target_label: "__address__"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - source_labels: ["__meta_consul_dc"]
        target_label: "consul_dc"

  # -----------------------------------------------------------------------
  # Cloudflared Tunnel metrics - Consul service discovery
  # -----------------------------------------------------------------------
  - job_name: "cloudflared-tunnel"
    scheme: "http"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "192.168.68.61:8500"
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
  # Consul cluster metrics
  # -----------------------------------------------------------------------
  - job_name: "consul"
    metrics_path: "/v1/agent/metrics"
    params:
      format: ["prometheus"]
    scheme: "http"
    authorization:
      credentials_file: "/etc/prometheus/secrets/consul_token"
    consul_sd_configs:
      - server: "192.168.68.61:8500"
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
    consul_sd_configs:
      - server: "192.168.68.61:8500"
        scheme: "http"
        services: ["traefik"]
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address"]
        regex: "(.+)"
        target_label: "__address__"
        replacement: "$1:8081"
      - source_labels: ["__meta_consul_service"]
        target_label: "service"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  # -----------------------------------------------------------------------
  # Blackbox Exporter - Consul service discovery
  # -----------------------------------------------------------------------
  - job_name: "blackbox"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "192.168.68.61:8500"
        scheme: "http"
        services: ["blackbox-exporter"]
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
      - server: "192.168.68.61:8500"
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
  # PostgreSQL Replica Exporter - Replica metrics via Consul SD
  # -----------------------------------------------------------------------
  - job_name: "postgres-replica-exporter"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "192.168.68.61:8500"
        scheme: "http"
        services: ["postgres-replica-exporter"]
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
        replacement: "replica"

  # -----------------------------------------------------------------------
  # Redis Exporter - Cache metrics via Consul service discovery
  # -----------------------------------------------------------------------
  - job_name: "redis-exporter"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "192.168.68.61:8500"
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
      - server: "192.168.68.61:8500"
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
          - "https://resume.alexfreidah.com/"
          - "https://k3s-status.alexfreidah.com/"
          # Public munchbox.cc services (via Cloudflare tunnel, no Authentik)
          - "https://jellyfin.munchbox.cc/"
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__param_target"
      - source_labels: ["__param_target"]
        target_label: "instance"
      - target_label: "__address__"
        replacement: "blackbox-exporter.service.consul:9115"

  # -----------------------------------------------------------------------
  # Alertmanager - Self-monitoring for alerting system health
  # -----------------------------------------------------------------------
  - job_name: "alertmanager"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "192.168.68.61:8500"
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
      - server: "192.168.68.61:8500"
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
      - server: "192.168.68.61:8500"
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
