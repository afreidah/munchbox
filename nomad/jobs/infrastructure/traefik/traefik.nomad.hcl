# -------------------------------------------------------------------------------
# Traefik — Reverse Proxy and Load Balancer
#
# Project: Munchbox / Author: Alex Freidah
#
# HTTPS-first ingress controller running as system job on ingress nodes.
# Active-passive HA with Keepalived VIP failover between goren and
# nomad-client-05. Auto-discovers services via Consul Catalog, manages TLS
# certs via built-in ACME with Cloudflare DNS challenge.
#
# Each instance independently obtains and renews certs — no shared storage
# needed. Rolling updates: one node at a time, VIP floats to standby.
#
# Cloudflare tunnel connector runs as a poststart sidecar so its lifecycle
# is tied to Traefik — if Traefik dies, the connector stops and Cloudflare
# routes all traffic to the healthy connector on the other ingress node.
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
    version     = "3.6.9"
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
  # Placement — Run on ingress nodes only
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

      port "gitssh" {
        static = 2222
      }

      port "log-agent" {
        static = 5000
      }

      port "log-dashboard" {
        static = 3000
      }

      port "cloudflared-metrics" {
        static = 2000
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
        image        = "traefik:v3.7.5"
        network_mode = "host"
        ports        = ["http", "https", "dashboard", "gitssh"]
        volumes      = [
          "local/traefik.toml:/etc/traefik/traefik.toml:ro",
          "local/traefik_dynamic.toml:/etc/traefik/traefik_dynamic.toml:ro",
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
{{- end }}
{{ with secret "secret/data/nomad-ui" -}}
NOMAD_UI_TOKEN={{ .Data.data.token }}
{{- end }}
EOH
      }

      # --- Wildcard cert from Vault (issued by the cert-acquirer job). Both
      #     ingress instances render the SAME cert, replacing per-instance ACME.
      #     change_mode=noop: Traefik's file provider hot-reloads cert files on
      #     change, so a weekly cert rotation needs no restart. ---
      template {
        destination = "secrets/wildcard.crt"
        change_mode = "noop"
        data        = <<EOH
{{ with secret "secret/data/traefik/wildcard" }}{{ .Data.data.cert }}{{ end }}
EOH
      }

      template {
        destination = "secrets/wildcard.key"
        change_mode = "noop"
        data        = <<EOH
{{ with secret "secret/data/traefik/wildcard" }}{{ .Data.data.key }}{{ end }}
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
  filePath = "/alloc/data/access.log"
  format = "json"
  bufferingSize = 100
  [accessLog.filters]
    statusCodes = ["200-599"]
    retryAttempts = true
    minDuration = "0ms"
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

# --- Wildcard cert from Vault (rendered by the secrets/wildcard.{crt,key}
#     templates above; issued centrally by the cert-acquirer job). Registered
#     as a certificate AND set as the default so unmatched SNI also gets it. ---
[[tls.certificates]]
  certFile = "/secrets/wildcard.crt"
  keyFile  = "/secrets/wildcard.key"

[tls.stores.default]
  [tls.stores.default.defaultCertificate]
    certFile = "/secrets/wildcard.crt"
    keyFile  = "/secrets/wildcard.key"

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
    middlewares = ["dashboard-allowlan"]
    [http.routers.consul.tls]

  # --- Consul UI (HTTP, for CF tunnel) ---
  [http.routers.consul-http]
    rule        = "Host(`consul.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "consul-ui"
    middlewares = ["cf-tunnel-https", "oauth2-proxy-errors", "oauth2-proxy"]

  # --- Nomad UI (HTTPS, LAN-only) ---
  [http.routers.nomad]
    rule        = "Host(`nomad.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "nomad-ui"
    middlewares = ["oauth2-proxy-errors", "oauth2-proxy", "dashboard-allowlan", "nomad-token"]
    [http.routers.nomad.tls]

  # --- Nomad UI (HTTP, for CF tunnel) ---
  [http.routers.nomad-http]
    rule        = "Host(`nomad.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "nomad-ui"
    middlewares = ["cf-tunnel-https", "oauth2-proxy-errors", "oauth2-proxy", "nomad-token"]

  # --- Traefik Dashboard (HTTPS, LAN-only) ---
  [http.routers.traefik-dashboard]
    rule        = "Host(`traefik.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "api@internal"
    middlewares = ["oauth2-proxy-errors", "oauth2-proxy", "dashboard-allowlan", "dashboard-redirect"]
    [http.routers.traefik-dashboard.tls]

  # --- Traefik Dashboard (HTTP, for CF tunnel) ---
  [http.routers.traefik-dashboard-http]
    rule        = "Host(`traefik.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "api@internal"
    middlewares = ["cf-tunnel-https", "oauth2-proxy-errors", "oauth2-proxy", "dashboard-redirect"]

  # --- Traefik Dashboard fallback on :8081 ---
  [http.routers.traefik-fallback]
    rule        = "PathPrefix(`/dashboard`) || PathPrefix(`/api`)"
    entryPoints = ["traefik"]
    service     = "api@internal"
    middlewares = ["oauth2-proxy-errors", "oauth2-proxy", "dashboard-allowlan"]
    priority    = 2

  # --- Proxmox UI (HTTPS, LAN-only) ---
  [http.routers.proxmox]
    rule        = "Host(`proxmox.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "proxmox-ui"
    middlewares = ["oauth2-proxy-errors", "oauth2-proxy", "dashboard-allowlan"]
    [http.routers.proxmox.tls]

  # --- Proxmox UI (HTTP, for CF tunnel) ---
  [http.routers.proxmox-http]
    rule        = "Host(`proxmox.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "proxmox-ui"
    middlewares = ["cf-tunnel-https", "oauth2-proxy-errors", "oauth2-proxy"]

  # --- Vault UI (HTTPS, LAN-only) ---
  [http.routers.vault]
    rule        = "Host(`vault.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "vault-ui"
    middlewares = ["oauth2-proxy-errors", "oauth2-proxy", "dashboard-allowlan", "vault-theme"]
    [http.routers.vault.tls]

  # --- Vault UI (HTTP, for CF tunnel) ---
  [http.routers.vault-http]
    rule        = "Host(`vault.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "vault-ui"
    middlewares = ["cf-tunnel-https", "oauth2-proxy-errors", "oauth2-proxy", "vault-theme"]


  # --- ZFS Watcher (HTTPS, LAN-only) ---
  [http.routers.zfswatcher]
    rule        = "Host(`zfs.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "zfswatcher"
    middlewares = ["oauth2-proxy-errors", "oauth2-proxy", "dashboard-allowlan", "zfswatcher-auth"]
    [http.routers.zfswatcher.tls]

  # --- ZFS Watcher (HTTP, for CF tunnel) ---
  [http.routers.zfswatcher-http]
    rule        = "Host(`zfs.munchbox.cc`)"
    entryPoints = ["web"]
    service     = "zfswatcher"
    middlewares = ["cf-tunnel-https", "oauth2-proxy-errors", "oauth2-proxy", "zfswatcher-auth"]

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

  # --- OAuth2 Proxy Forward Auth ---
  [http.middlewares.oauth2-proxy.forwardAuth]
    address              = "http://oauth2-proxy.service.consul:4180/oauth2/auth"
    trustForwardHeader   = true
    maxResponseBodySize  = 1048576
    authResponseHeaders  = [
      "X-Auth-Request-User",
      "X-Auth-Request-Email",
      "X-Auth-Request-Access-Token"
    ]

  # --- OAuth2 Proxy Error Handler (redirects 401 directly to OAuth flow) ---
  # Skip the /oauth2/sign_in HTML page — its button is fragile when the
  # request carries an `rd` parameter (CSRF cookie / SameSite / double
  # URL-encoding issues). /oauth2/start fires the OAuth flow immediately,
  # so the user goes straight from a protected page to Google and back,
  # no intermediate oauth2-proxy UI. The HTML sign-in page only matters
  # for multi-provider setups, which we don't run.
  [http.middlewares.oauth2-proxy-errors.errors]
    status  = ["401"]
    service = "oauth2-proxy-signin"
    query   = "/oauth2/start?rd={url}"

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

  # --- OAuth2-Proxy rate limiting (auth.munchbox.cc) ---
  [http.middlewares.auth-ratelimit.rateLimit]
    average = 10
    burst   = 20
    [http.middlewares.auth-ratelimit.rateLimit.sourceCriterion]
      requestHeaderName = "CF-Connecting-IP"

  # --- Jellyfin rate limiting ---
  [http.middlewares.jellyfin-ratelimit.rateLimit]
    average = 50
    burst   = 100
    [http.middlewares.jellyfin-ratelimit.rateLimit.sourceCriterion]
      requestHeaderName = "CF-Connecting-IP"

  # --- Forgejo API rate limiting ---
  [http.middlewares.forgejo-api-ratelimit.rateLimit]
    average = 100
    burst   = 200
    [http.middlewares.forgejo-api-ratelimit.rateLimit.sourceCriterion]
      requestHeaderName = "CF-Connecting-IP"

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

  # --- ZFS Watcher Basic Auth passthrough (real auth handled by OAuth2-proxy) ---
  [http.middlewares.zfswatcher-auth.headers]
    [http.middlewares.zfswatcher-auth.headers.customRequestHeaders]
{{ with secret "secret/data/zfswatcher" -}}
      Authorization = "Basic {{ printf "%s:%s" .Data.data.proxy_user .Data.data.proxy_password | base64Encode }}"
{{- end }}

  # --- Vault CSS injection (Catppuccin Mocha theme) ---
  [http.middlewares.vault-theme.plugin.rewritebody]
    lastModified = true
    [[http.middlewares.vault-theme.plugin.rewritebody.rewrites]]
      regex = "</head>"
      replacement = "<link rel=\"stylesheet\" href=\"http://themes.munchbox.cc/css/vault.css\"></head>"


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

  # --- OAuth2 Proxy Sign-in (for error redirect) ---
  [http.services.oauth2-proxy-signin.loadBalancer]
    [[http.services.oauth2-proxy-signin.loadBalancer.servers]]
      url = "http://oauth2-proxy.service.consul:4180"

  # --- ZFS Watcher (on rubirosa) ---
  [http.services.zfswatcher.loadBalancer]
    [[http.services.zfswatcher.loadBalancer.servers]]
      url = "http://192.168.68.69:8800"

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
        tags     = ["traefik.enable=false", "metrics", "scrape-port=8081"]

        check {
          name            = "traefik-https"
          type            = "http"
          protocol        = "https"
          port            = "https"
          path            = "/ping"
          header {
            Host = ["traefik.munchbox.cc"]
          }
          tls_server_name = "traefik.munchbox.cc"
          tls_skip_verify = true
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
        memory     = 768
        memory_max = 1024
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }

    # -----------------------------------------------------------------------
    # Task: geoip-updater (prestart)
    # Downloads MaxMind GeoLite2 databases for geolocation
    # -----------------------------------------------------------------------

    task "geoip-updater" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image = "maxmindinc/geoipupdate:v7"
      }

      template {
        destination = "secrets/geoip.env"
        env         = true
        data        = <<EOH
{{ with secret "secret/data/maxmind" }}
GEOIPUPDATE_ACCOUNT_ID={{ .Data.data.account_id }}
GEOIPUPDATE_LICENSE_KEY={{ .Data.data.license_key }}
{{ end }}
GEOIPUPDATE_EDITION_IDS=GeoLite2-City GeoLite2-Country
GEOIPUPDATE_DB_DIR=/alloc/data
EOH
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    # -----------------------------------------------------------------------
    # Task: traefik-log-filter
    # Filters out Nomad blocking queries (index=) from access logs
    # -----------------------------------------------------------------------

    task "traefik-log-filter" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "busybox:1.38.0"
        network_mode = "host"
        # Filter out long-poll/websocket connections that skew response time metrics:
        # - Nomad blocking queries (index=)
        # - SignalR real-time connections (signalr)
        args         = ["sh", "-c", "tail -F /alloc/data/access.log | grep -vE 'index=|signalr' > /alloc/data/access-filtered.log"]
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    # -----------------------------------------------------------------------
    # Task: traefik-log-agent
    # Parses Traefik access logs and exposes metrics API for dashboard
    # -----------------------------------------------------------------------

    task "traefik-log-agent" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image        = "hhftechnology/traefik-log-dashboard-agent:3.1.1"
        network_mode = "host"
        ports        = ["log-agent"]
      }

      template {
        destination = "secrets/agent.env"
        env         = true
        data        = <<EOH
{{ with secret "secret/data/traefik-log-dashboard" }}
TRAEFIK_LOG_DASHBOARD_AUTH_TOKEN={{ .Data.data.auth_token }}
{{ end }}
TRAEFIK_LOG_DASHBOARD_ACCESS_PATH=/alloc/data/access-filtered.log
EOH
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    # -----------------------------------------------------------------------
    # Task: traefik-log-dashboard
    # Web UI for viewing Traefik traffic analytics
    # -----------------------------------------------------------------------

    task "traefik-log-dashboard" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image        = "hhftechnology/traefik-log-dashboard:3.1.1"
        network_mode = "host"
        ports        = ["log-dashboard"]
      }

      template {
        destination = "secrets/dashboard.env"
        env         = true
        data        = <<EOH
{{ with secret "secret/data/traefik-log-dashboard" }}
AGENT_API_TOKEN={{ .Data.data.auth_token }}
{{ end }}
AGENT_API_URL=http://127.0.0.1:5000
PORT=3000
GEOIP_DB_PATH=/alloc/data/GeoLite2-City.mmdb
EOH
      }

      resources {
        cpu    = 150
        memory = 128
      }
    }

    # -----------------------------------------------------------------------
    # Service: traefik-log-dashboard
    # -----------------------------------------------------------------------

    service {
      name     = "traefik-log-dashboard"
      port     = "log-dashboard"
      provider = "consul"
      tags     = [
        "traefik.enable=true",
        # HTTPS router (LAN)
        "traefik.http.routers.traefik-logs.rule=Host(`traefik-logs.munchbox.cc`)",
        "traefik.http.routers.traefik-logs.entrypoints=websecure",
        "traefik.http.routers.traefik-logs.tls=true",
        "traefik.http.routers.traefik-logs.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file,dashboard-allowlan@file",
        # HTTP router (CF tunnel)
        "traefik.http.routers.traefik-logs-http.rule=Host(`traefik-logs.munchbox.cc`)",
        "traefik.http.routers.traefik-logs-http.entrypoints=web",
        "traefik.http.routers.traefik-logs-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file"
      ]

      check {
        name     = "traefik-log-dashboard-health"
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -----------------------------------------------------------------------
    # Task: cloudflared-tunnel (poststart sidecar)
    # Cloudflare tunnel connector — tied to Traefik lifecycle so the
    # connector stops when Traefik dies, preventing Cloudflare from routing
    # traffic to a node with no working reverse proxy.
    # Tunnel ingress configuration is managed by Terragrunt
    # (infrastructure/terragrunt/modules/dns/main.tf) via cloudflare_tunnel_config.
    # -----------------------------------------------------------------------

    task "cloudflared-tunnel" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "cloudflare/cloudflared:2026.5.2"
        image_pull_timeout = "10m"
        ports              = ["cloudflared-metrics"]
        network_mode       = "host"
        args = [
          "tunnel",
          "--metrics", "0.0.0.0:2000",
          "run",
          "--token", "${TUNNEL_TOKEN}"
        ]
      }

      # --- Tunnel token from Vault ---
      template {
        data        = <<EOH
{{ with secret "secret/data/cloudflared" }}
TUNNEL_TOKEN={{ .Data.data.tunnel_token }}
{{ end }}
EOH
        destination = "secrets/cloudflared.env"
        env         = true
        change_mode = "restart"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }

    # -----------------------------------------------------------------------
    # Service: cloudflared-tunnel
    # -----------------------------------------------------------------------

    service {
      name     = "cloudflared-tunnel"
      port     = "cloudflared-metrics"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "metrics",
        "infrastructure",
        "cloudflare",
        "tunnel",
        "ingress",
      ]

      check {
        name     = "cloudflared-tunnel-health"
        type     = "http"
        path     = "/ready"
        port     = "cloudflared-metrics"
        interval = "10s"
        timeout  = "3s"
      }
    }
  }
}
