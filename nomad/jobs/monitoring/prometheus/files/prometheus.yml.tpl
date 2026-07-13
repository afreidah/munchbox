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
# Read through /local/ (Nomad's built-in alloc-local dir mount) rather than
# the pack's single-file bind at /etc/prometheus/config/alert_rules.yml.
# Single-file binds latch to an inode at container start; consul-template's
# rename-on-write swaps the inode every render, leaving the file mount
# pointing at the orphaned original. Directory mounts re-resolve per open,
# so /local/alert_rules.yml always reflects the latest render.
rule_files:
  - /local/alert_rules.yml

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
  # Auto-discovery: any Consul service tagged `metrics` gets scraped.
  # Defaults: service's registered port + /metrics path + global scrape
  # interval/timeout. Tag overrides (all optional):
  #   scrape-port=<n>      - port <n> instead of the registered service port
  #   scrape-path=<p>      - path <p> instead of /metrics
  #   scrape-interval=<d>  - prom duration string instead of 15s
  #   scrape-timeout=<d>   - prom duration string instead of 10s
  #   scrape-job=<name>    - job label <name> instead of consul service name
  # instance label = consul node name.
  # -----------------------------------------------------------------------
  - job_name: "consul-auto"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
    relabel_configs:
      # --- keep only services with the `metrics` tag ---
      - source_labels: ["__meta_consul_tags"]
        regex: ".*,metrics,.*"
        action: keep
      # --- job label = consul service name ---
      - source_labels: ["__meta_consul_service"]
        target_label: "job"
      # --- instance label = consul node ---
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      # --- optional scrape-path override (tag `scrape-path=/foo`) ---
      - source_labels: ["__meta_consul_tags"]
        regex: ".*,scrape-path=([^,]+),.*"
        target_label: "__metrics_path__"
        replacement: "$1"
      # --- optional scrape-port override (tag `scrape-port=9617`) ---
      # NB: single-$ form. HCL2 eats `${1}` as interpolation and renders `1`.
      - source_labels: ["__address__", "__meta_consul_tags"]
        separator: ";"
        regex: "([^:]+):[0-9]+;.*,scrape-port=([0-9]+),.*"
        target_label: "__address__"
        replacement: "$1:$2"
      # --- optional scrape-interval override (tag `scrape-interval=30s`) ---
      - source_labels: ["__meta_consul_tags"]
        regex: ".*,scrape-interval=([^,]+),.*"
        target_label: "__scrape_interval__"
        replacement: "$1"
      # --- optional scrape-timeout override (tag `scrape-timeout=25s`) ---
      - source_labels: ["__meta_consul_tags"]
        regex: ".*,scrape-timeout=([^,]+),.*"
        target_label: "__scrape_timeout__"
        replacement: "$1"
      # --- optional job label override (tag `scrape-job=node-exporter`) ---
      - source_labels: ["__meta_consul_tags"]
        regex: ".*,scrape-job=([^,]+),.*"
        target_label: "job"
        replacement: "$1"

  # -----------------------------------------------------------------------
  # dnsdist - its /metrics requires the apiKey, so it can't ride the
  # unauthenticated consul-auto job. Dedicated job; basic_auth password is the
  # apiKey (access_key) with any username. Discovered by consul service name.
  # -----------------------------------------------------------------------
  - job_name: "dnsdist"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        scheme: "http"
        datacenter: "munchbox"
        token: "{{ with secret "secret/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}"
        services: ["dnsdist"]
    basic_auth:
      username: "x"
      password: "{{ with secret "secret/data/dnsdist" }}{{ .Data.data.access_key }}{{ end }}"
    relabel_configs:
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

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
  # Internal site monitoring — probed from inside the network through the
  # internal blackbox so *.munchbox.cc resolves to the VIP and hits Traefik
  # directly (not the Cloudflare tunnel). https_2xx validates the cert too.
  # -----------------------------------------------------------------------
  - job_name: "site_http"
    metrics_path: "/probe"
    params:
      module: ["https_2xx"]
    static_configs:
      - targets:
          - "https://s3-orchestrator.munchbox.cc/"
          - "https://oracle-watchdog.munchbox.cc/"
          - "https://cloudflare-log-collector.munchbox.cc/"
          - "https://g3.munchbox.cc/"
          - "https://nomad-temporal-jobs.munchbox.cc/"
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__param_target"
      - source_labels: ["__param_target"]
        target_label: "instance"
      - target_label: "__address__"
        replacement: "blackbox-exporter-internal.service.consul:9115"

  # -----------------------------------------------------------------------
  # Pi-hole probes — green + logan admin UIs. pihole-*.munchbox.cc resolve
  # to the Traefik VIP (like every catalog service), which fronts the admin
  # over HTTPS with a valid cert, so this must be https_2xx. Through the
  # internal blackbox so a WireGuard flap doesn't fake a pihole outage.
  # -----------------------------------------------------------------------
  - job_name: "pihole_probes"
    metrics_path: "/probe"
    params:
      module: ["https_2xx"]
    static_configs:
      - targets:
          - "https://pihole-green.munchbox.cc/admin/"
          - "https://pihole-logan.munchbox.cc/admin/"
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__param_target"
      - source_labels: ["__param_target"]
        target_label: "instance"
      - target_label: "__address__"
        replacement: "blackbox-exporter-internal.service.consul:9115"

  # -----------------------------------------------------------------------
  # Aptly - Debian package repository metrics
  # -----------------------------------------------------------------------
  - job_name: "aptly"
    metrics_path: "/api/metrics"
    basic_auth:
      username: "admin"
      password: "{{ with secret "secret/data/aptly-admin" }}{{ .Data.data.password }}{{ end }}"
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
  # Proxmox VE Exporter - Hypervisor metrics (CPU, memory, disk, network)
  # -----------------------------------------------------------------------
  - job_name: "pve"
    metrics_path: "/pve"
    # --- 60s: each scrape enumerates the whole cluster via the PVE API; 15s pegs the exporter ---
    scrape_interval: 60s
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
