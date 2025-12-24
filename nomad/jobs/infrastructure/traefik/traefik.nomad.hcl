# -------------------------------------------------------------------------------
# Traefik — Reverse Proxy and Load Balancer
#
# Project: Munchbox / Author: Alex Freidah
#
# HTTPS-first ingress controller running as system job on ingress node.
# Auto-discovers services via Consul Catalog, fetches TLS certs from Let's Encrypt
# via Cloudflare DNS challenge, and exposes dashboard on :8081 (LAN-only).
#
# Note: Zero-downtime updates require running on multiple ingress nodes.
# With a single node and static ports, brief downtime during updates is expected.
# -------------------------------------------------------------------------------

job "traefik" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "system"
  node_pool   = "all"
  priority    = 90

  # -------------------------------------------------------------------------
  # Metadata
  # -------------------------------------------------------------------------

  meta {
    managed_by  = "nomad"
    project     = "munchbox"
    version     = "3.5.3"
    tier        = "tier-0"
  }

  # -------------------------------------------------------------------------
  # Update Strategy
  # -------------------------------------------------------------------------

  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
    stagger          = "30s"
  }

  # -------------------------------------------------------------------------
  # Placement — Pin to ingress nodes
  # -------------------------------------------------------------------------

  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  # -------------------------------------------------------------------------
  # Task Group: traefik
  # -------------------------------------------------------------------------

  group "traefik" {

    # --- Network Configuration ---
    network {
      mode = "host"

      port "http" {
        static = 80
      }

      port "https" {
        static = 443
      }

      port "dashboard" {
        static = 8081
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # -----------------------------------------------------------------------
    # Task: traefik
    # -----------------------------------------------------------------------

    task "traefik" {
      driver = "docker"

      # --- Vault Integration ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image        = "traefik:v3.6.4"
        network_mode = "host"
        ports        = ["http", "https", "dashboard"]
        volumes      = [
          "local/traefik.toml:/etc/traefik/traefik.toml:ro",
          "local/traefik_dynamic.toml:/etc/traefik/traefik_dynamic.toml:ro",
          # Let's Encrypt certs from shared NFS (managed by certbot job)
          "/mnt/gdrive/munchbox-data/certbot/traefik/munchbox.crt:/etc/traefik/certs/munchbox.crt:ro",
          "/mnt/gdrive/munchbox-data/certbot/traefik/munchbox.key:/etc/traefik/certs/munchbox.key:ro",
          "/etc/nomad.d/tls/ca-chain.crt:/etc/traefik/certs/ca-chain.crt:ro"
        ]
      }

      # --- Consul Token and Cloudflare Token from Vault ---
      template {
        destination = "secrets/traefik.env"
        env         = true
        data        = <<EOH
{{ with secret "secret/data/traefik" -}}
CONSUL_HTTP_TOKEN={{ .Data.data.consul_token }}
CF_DNS_API_TOKEN={{ .Data.data.cloudflare_api_token }}
{{- end }}
{{ with secret "secret/data/nomad-ui" -}}
NOMAD_UI_TOKEN={{ .Data.data.token }}
{{- end }}
EOH
      }

      # --- Traefik Static Configuration ---
      template {
        destination = "local/traefik.toml"
        change_mode = "restart"
        data        = <<EOH
# -------------------------------------------------------------------------
# Traefik Static Configuration
# -------------------------------------------------------------------------

[entryPoints]
  [entryPoints.web]
    address = ":80"
    [entryPoints.web.forwardedHeaders]
      trustedIPs = ["127.0.0.1/32"]
    [entryPoints.web.http]
      middlewares = ["default-sec@file"]

  [entryPoints.websecure]
    address = ":443"
    [entryPoints.websecure.forwardedHeaders]
      trustedIPs = ["127.0.0.1/32"]
    [entryPoints.websecure.http]
      middlewares = ["default-sec@file"]

  [entryPoints.traefik]
    address = ":8081"

[api]
  dashboard = true
  insecure  = false

[ping]
  entryPoint = "traefik"

# -------------------------------------------------------------------------
# Prometheus Metrics
# -------------------------------------------------------------------------

[metrics]
  [metrics.prometheus]
    entryPoint           = "traefik"
    addEntryPointsLabels = true
    addServicesLabels    = true

# -------------------------------------------------------------------------
# Consul Catalog Provider
# -------------------------------------------------------------------------

[providers.consulCatalog]
  refreshInterval  = "5s"
  prefix           = "traefik"
  exposedByDefault = false

  [providers.consulCatalog.endpoint]
    address = "127.0.0.1:8500"
{{ with secret "secret/data/traefik" -}}
    token   = "{{ .Data.data.consul_token }}"
{{- end }}

# -------------------------------------------------------------------------
# File Provider (dynamic config)
# -------------------------------------------------------------------------

[providers.file]
  filename = "/etc/traefik/traefik_dynamic.toml"

[accessLog]
  format = "json"
  [accessLog.fields]
    [accessLog.fields.names]
      StartUTC         = "keep"
      Duration         = "keep"
      RouterName       = "keep"
      ServiceName      = "keep"
      ServiceURL       = "keep"
      ClientHost       = "keep"
      RequestMethod    = "keep"
      RequestPath      = "keep"
      RequestProtocol  = "keep"
      OriginStatus     = "keep"
      DownstreamStatus = "keep"
      RequestCount     = "keep"
      entryPointName   = "keep"
    [accessLog.fields.headers]
      defaultMode = "drop"
      [accessLog.fields.headers.names]
        User-Agent       = "keep"
        X-Forwarded-For  = "keep"
        CF-Connecting-IP = "keep"

[log]
  level = "INFO"

# -------------------------------------------------------------------------
# Plugins (for CSS injection)
# -------------------------------------------------------------------------

[experimental.plugins.rewritebody]
  modulename = "github.com/traefik/plugin-rewritebody"
  version = "v0.3.1"

# -------------------------------------------------------------------------
# Tracing (Tempo via OpenTelemetry)
# -------------------------------------------------------------------------

[tracing]
  serviceName = "traefik"
  sampleRate = 1.0
  [tracing.otlp]
    [tracing.otlp.grpc]
      endpoint = "tempo.service.consul:4317"
      insecure = true

# -------------------------------------------------------------------------
# ACME Resolver (kept for Consul Catalog service compatibility)
# Actual certs are loaded from files managed by certbot job
# -------------------------------------------------------------------------

[certificatesResolvers.letsencrypt.acme]
  email = "alex@alexfreidah.com"
  storage = "/tmp/acme.json"
  [certificatesResolvers.letsencrypt.acme.dnsChallenge]
    provider = "cloudflare"
    resolvers = ["1.1.1.1:53", "8.8.8.8:53"]
EOH
      }

      # --- Traefik Dynamic Configuration ---
      template {
        destination = "local/traefik_dynamic.toml"
        change_mode = "restart"
        data        = <<EOH
# -------------------------------------------------------------------------
# Traefik Dynamic Configuration
# -------------------------------------------------------------------------

# --- TLS Certificates (managed by certbot, stored in Vault) ---
[[tls.certificates]]
  certFile = "/etc/traefik/certs/munchbox.crt"
  keyFile  = "/etc/traefik/certs/munchbox.key"

# --- Default TLS Store ---
[tls.stores]
  [tls.stores.default]
    [tls.stores.default.defaultCertificate]
      certFile = "/etc/traefik/certs/munchbox.crt"
      keyFile  = "/etc/traefik/certs/munchbox.key"

# --- TLS Options ---
[tls.options]
  [tls.options.default]
    minVersion = "VersionTLS12"
    sniStrict  = false

# -------------------------------------------------------------------------
# HTTP Routers
# -------------------------------------------------------------------------

[http.routers]

  # --- HTTP to HTTPS redirect for *.munchbox.cc ---
  [http.routers.http-redirect]
    rule        = "HostRegexp(`{host:.+\\.munchbox\\.cc}`)"
    entryPoints = ["web"]
    middlewares = ["redirect-https"]
    service     = "noop@internal"
    priority    = 1

  # --- Consul UI (HTTPS, LAN-only) ---
  [http.routers.consul]
    rule        = "Host(`consul.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "consul-ui"
    middlewares = ["authentik", "dashboard-allowlan"]
    [http.routers.consul.tls]

  # --- Consul UI (HTTP, for CF tunnel) ---
  [http.routers.consul-http]
    rule        = "Host(`consul.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "consul-ui"
    middlewares = ["cf-tunnel-https", "authentik"]

  # --- Nomad UI (HTTPS, LAN-only) ---
  [http.routers.nomad]
    rule        = "Host(`nomad.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "nomad-ui"
    middlewares = ["authentik", "dashboard-allowlan", "nomad-token"]
    [http.routers.nomad.tls]

  # --- Nomad UI (HTTP, for CF tunnel) ---
  [http.routers.nomad-http]
    rule        = "Host(`nomad.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "nomad-ui"
    middlewares = ["cf-tunnel-https", "authentik", "nomad-token"]

  # --- Traefik Dashboard (HTTPS, LAN-only) ---
  [http.routers.traefik-dashboard]
    rule        = "Host(`traefik.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "api@internal"
    middlewares = ["authentik", "dashboard-allowlan", "dashboard-redirect"]
    [http.routers.traefik-dashboard.tls]

  # --- Traefik Dashboard (HTTP, for CF tunnel) ---
  [http.routers.traefik-dashboard-http]
    rule        = "Host(`traefik.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "api@internal"
    middlewares = ["cf-tunnel-https", "authentik", "dashboard-redirect"]

  # --- Traefik Dashboard fallback on :8081 ---
  [http.routers.traefik-fallback]
    rule        = "PathPrefix(`/dashboard`) || PathPrefix(`/api`)"
    entryPoints = ["traefik"]
    service     = "api@internal"
    middlewares = ["authentik", "dashboard-allowlan"]
    priority    = 2

  # --- Proxmox UI (HTTPS, LAN-only) ---
  [http.routers.proxmox]
    rule        = "Host(`proxmox.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "proxmox-ui"
    middlewares = ["authentik", "dashboard-allowlan"]
    [http.routers.proxmox.tls]

  # --- Proxmox UI (HTTP, for CF tunnel) ---
  [http.routers.proxmox-http]
    rule        = "Host(`proxmox.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "proxmox-ui"
    middlewares = ["cf-tunnel-https", "authentik"]

  # --- Vault UI (HTTPS, LAN-only) ---
  [http.routers.vault]
    rule        = "Host(`vault.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "vault-ui"
    middlewares = ["authentik", "dashboard-allowlan", "vault-theme"]
    [http.routers.vault.tls]

  # --- Vault UI (HTTP, for CF tunnel) ---
  [http.routers.vault-http]
    rule        = "Host(`vault.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "vault-ui"
    middlewares = ["cf-tunnel-https", "authentik", "vault-theme"]

  # --- Theme Server (HTTPS, internal CSS files) ---
  [http.routers.themes]
    rule        = "Host(`themes.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "theme-server"
    [http.routers.themes.tls]

  # --- Theme Server (HTTP, internal) ---
  [http.routers.themes-http]
    rule        = "Host(`themes.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "theme-server"

  # --- Health check endpoint (no auth) ---
  [http.routers.ping]
    rule        = "Host(`traefik.munchbox.cc`) && Path(`/ping`)"
    entryPoints = ["websecure"]
    service     = "ping@internal"
    [http.routers.ping.tls]

# -------------------------------------------------------------------------
# HTTP Middlewares
# -------------------------------------------------------------------------

[http.middlewares]

  # --- Authentik Forward Auth (domain-level SSO) ---
  # Using direct IP since system DNS doesn't resolve .service.consul properly
  [http.middlewares.authentik.forwardAuth]
    address              = "http://192.168.68.61:9000/outpost.goauthentik.io/auth/traefik"
    trustForwardHeader   = true
    authResponseHeaders  = [
      "X-authentik-username",
      "X-authentik-groups",
      "X-authentik-email",
      "X-authentik-name",
      "X-authentik-uid"
    ]

  # --- HTTPS redirect ---
  [http.middlewares.redirect-https.redirectScheme]
    scheme    = "https"
    permanent = true

  # --- LAN-only access ---
  [http.middlewares.dashboard-allowlan.ipAllowList]
    sourceRange = ["192.168.68.0/24", "10.200.0.0/24", "127.0.0.1/32"]

  # --- Dashboard root redirect ---
  [http.middlewares.dashboard-redirect.redirectRegex]
    regex       = "^https?://traefik\\.munchbox\\.cc/?$"
    replacement = "https://traefik.munchbox.cc/dashboard/"
    permanent   = true

  # --- Resume www redirect ---
  [http.middlewares.redirect-resume-www.redirectRegex]
    regex       = "^https?://www\\.resume\\.alexfreidah\\.com/(.*)"
    replacement = "https://resume.alexfreidah.com/$1"
    permanent   = true

  # --- Apex to resume redirect ---
  [http.middlewares.redirect-apex-to-resume.redirectRegex]
    regex       = "^https?://(www\\.)?alexfreidah\\.com/(.*)"
    replacement = "https://resume.alexfreidah.com/$2"
    permanent   = true

  # --- Resume rate limiting ---
  [http.middlewares.resume-ratelimit.rateLimit]
    average = 20
    burst   = 40
    [http.middlewares.resume-ratelimit.rateLimit.sourceCriterion]
      requestHeaderName = "CF-Connecting-IP"

  # --- Resume security headers ---
  [http.middlewares.resume-sec.headers]
    stsSeconds              = 31536000
    stsIncludeSubdomains    = true
    forceSTSHeader          = true
    contentTypeNosniff      = true
    customFrameOptionsValue = "SAMEORIGIN"
    referrerPolicy          = "no-referrer"
    contentSecurityPolicy   = "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' https://analytics.alexfreidah.com; connect-src 'self' https://analytics.alexfreidah.com; frame-ancestors 'self'"

  # --- k3s-status security headers ---
  [http.middlewares.k3s-status-sec.headers]
    stsSeconds              = 31536000
    stsIncludeSubdomains    = true
    forceSTSHeader          = true
    contentTypeNosniff      = true
    customFrameOptionsValue = "SAMEORIGIN"
    referrerPolicy          = "no-referrer"
    contentSecurityPolicy   = "default-src 'self' data: blob: https:; style-src 'self' 'unsafe-inline' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: https:; connect-src 'self' https: ws: wss:; worker-src 'self' blob:; frame-ancestors 'self'"
    [http.middlewares.k3s-status-sec.headers.customResponseHeaders]
      Cache-Control = "no-store, no-cache, must-revalidate"

  # --- Default security headers (for services without custom CSP) ---
  [http.middlewares.default-sec.headers]
    stsSeconds              = 31536000
    stsIncludeSubdomains    = true
    forceSTSHeader          = true
    contentTypeNosniff      = true
    browserXssFilter        = true
    customFrameOptionsValue = "SAMEORIGIN"
    referrerPolicy          = "strict-origin-when-cross-origin"

  # --- Nextcloud rate limiting ---
  [http.middlewares.nextcloud-ratelimit.rateLimit]
    average = 100
    burst   = 200
    [http.middlewares.nextcloud-ratelimit.rateLimit.sourceCriterion]
      requestHeaderName = "CF-Connecting-IP"

  # --- Nextcloud security headers ---
  [http.middlewares.nextcloud-sec.headers]
    stsSeconds              = 31536000
    stsIncludeSubdomains    = true
    stsPreload              = true
    forceSTSHeader          = true
    contentTypeNosniff      = true
    browserXssFilter        = true
    customFrameOptionsValue = "SAMEORIGIN"
    referrerPolicy          = "strict-origin-when-cross-origin"
    permissionsPolicy       = "camera=(), microphone=(), geolocation=(), payment=()"

  # --- Emby rate limiting ---
  [http.middlewares.emby-ratelimit.rateLimit]
    average = 100
    burst   = 200
    [http.middlewares.emby-ratelimit.rateLimit.sourceCriterion]
      requestHeaderName = "CF-Connecting-IP"

  # --- Emby security headers ---
  [http.middlewares.emby-sec.headers]
    stsSeconds              = 31536000
    stsIncludeSubdomains    = true
    forceSTSHeader          = true
    contentTypeNosniff      = true
    browserXssFilter        = true
    customFrameOptionsValue = "SAMEORIGIN"
    referrerPolicy          = "strict-origin-when-cross-origin"

  # --- Nomad UI token injection ---
  [http.middlewares.nomad-token.headers]
    [http.middlewares.nomad-token.headers.customRequestHeaders]
{{ with secret "secret/data/nomad-ui" -}}
      X-Nomad-Token = "{{ .Data.data.token }}"
{{- end }}

  # --- Cloudflare tunnel HTTPS header (for HTTP entrypoint traffic from CF tunnel) ---
  [http.middlewares.cf-tunnel-https.headers]
    [http.middlewares.cf-tunnel-https.headers.customRequestHeaders]
      X-Forwarded-Proto = "https"

  # --- Vault CSS injection (Catppuccin Mocha theme) ---
  [http.middlewares.vault-theme.plugin.rewritebody]
    lastModified = true
    [[http.middlewares.vault-theme.plugin.rewritebody.rewrites]]
      regex = "</head>"
      replacement = "<link rel=\"stylesheet\" href=\"http://themes.munchbox.cc/css/vault.css\"></head>"

  # --- Umami Analytics Injection ---
  # Injects Umami tracking script into HTML pages
  # Add this middleware to services you want to track
  [http.middlewares.umami-tracking.plugin.rewritebody]
    lastModified = true
    [[http.middlewares.umami-tracking.plugin.rewritebody.rewrites]]
      regex = "</head>"
      replacement = "<script defer src=\"https://analytics.munchbox.cc/script.js\" data-website-id=\"0ac921bc-72f6-4b31-9cf3-77de04fe6337\"></script></head>"

# -------------------------------------------------------------------------
# HTTP Services (non-Consul backends)
# -------------------------------------------------------------------------

[http.services]

  # --- Consul UI ---
  [http.services.consul-ui.loadBalancer]
    [[http.services.consul-ui.loadBalancer.servers]]
      url = "http://127.0.0.1:8500"

  # --- Nomad UI ---
  [http.services.nomad-ui.loadBalancer]
    serversTransport = "nomad-tls"
    # Extended timeouts for websockets/long-polling during deployments
    passHostHeader = true
    [http.services.nomad-ui.loadBalancer.responseForwarding]
      flushInterval = "100ms"
    [[http.services.nomad-ui.loadBalancer.servers]]
      url = "https://127.0.0.1:4646"

  # --- Proxmox UI ---
  [http.services.proxmox-ui.loadBalancer]
    serversTransport = "insecure"
    [[http.services.proxmox-ui.loadBalancer.servers]]
      url = "https://192.168.68.59:8006"

  # --- Vault UI ---
  [http.services.vault-ui.loadBalancer]
    serversTransport = "insecure"
    [[http.services.vault-ui.loadBalancer.servers]]
      url = "https://192.168.68.61:8200"

  # --- Theme Server (CSS files via WireGuard) ---
  [http.services.theme-server.loadBalancer]
    [[http.services.theme-server.loadBalancer.servers]]
      url = "http://10.200.0.12:8078"

# -------------------------------------------------------------------------
# Server Transports
# -------------------------------------------------------------------------

[http.serversTransports]
  [http.serversTransports.nomad-tls]
    rootCAs = ["/etc/traefik/certs/ca-chain.crt"]
    # Extended timeouts for Nomad UI streaming/websockets
    [http.serversTransports.nomad-tls.forwardingTimeouts]
      dialTimeout = "30s"
      responseHeaderTimeout = "0s"
      idleConnTimeout = "90s"
  [http.serversTransports.insecure]
    insecureSkipVerify = true
EOH
      }

      # --- Service Registration (HTTPS) ---
      service {
        name     = "traefik"
        port     = "https"
        provider = "consul"
        tags     = ["traefik.enable=false", "metrics_port=8081"]

        check {
          name            = "traefik-https-cert"
          type            = "http"
          protocol        = "https"
          port            = "https"
          path            = "/ping"
          header {
            Host = ["traefik.munchbox.cc"]
          }
          tls_server_name = "traefik.munchbox.cc"
          tls_skip_verify = false
          interval        = "10s"
          timeout         = "5s"
        }
      }

      # --- Service Registration (Dashboard) ---
      service {
        name     = "traefik-dashboard"
        port     = "dashboard"
        provider = "consul"
        tags     = ["traefik.enable=false"]

        check {
          name     = "traefik-ping"
          type     = "http"
          path     = "/ping"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # --- Resources ---
      resources {
        cpu    = 300
        memory = 256
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
