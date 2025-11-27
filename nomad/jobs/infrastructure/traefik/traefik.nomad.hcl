# -------------------------------------------------------------------------------
# Traefik — Reverse Proxy and Load Balancer
#
# Project: Munchbox / Author: Alex Freidah
#
# HTTPS-first ingress controller running as system job on ingress nodes.
# Auto-discovers services via Consul Catalog, fetches TLS certs from Vault PKI,
# and exposes dashboard on :8081 (LAN-only).
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
  # Placement
  # -------------------------------------------------------------------------

  # --- Pin to ingress nodes ---
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
        image        = "traefik:v3.5.3"
        network_mode = "host"
        ports        = ["http", "https", "dashboard"]
        volumes      = [
          "local/traefik.toml:/etc/traefik/traefik.toml:ro",
          "local/traefik_dynamic.toml:/etc/traefik/traefik_dynamic.toml:ro",
          "secrets/tls:/etc/traefik/tls:ro"
        ]
      }

      # --- Consul Token from Vault ---
      template {
        destination = "secrets/consul.env"
        env         = true
        data        = <<EOH
{{ with secret "secret/data/traefik" -}}
CONSUL_HTTP_TOKEN={{ .Data.data.consul_token }}
{{- end }}
EOH
      }

      # --- TLS Certificate and Key from Vault PKI (combined PEM) ---
      template {
        destination = "secrets/tls/munchbox.pem"
        change_mode = "restart"
        perms       = "0600"
        data        = <<EOH
{{ with pkiCert "pki_int/issue/traefik" "common_name=*.munchbox.cc" "ttl=720h" -}}
{{ .Cert }}
{{ .CA }}
{{ .Key }}
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

  [entryPoints.websecure]
    address = ":443"
    [entryPoints.websecure.forwardedHeaders]
      trustedIPs = ["127.0.0.1/32"]

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
  refreshInterval  = "15s"
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

[log]
  level = "INFO"
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

# --- TLS Certificates (from Vault PKI - combined PEM) ---
[[tls.certificates]]
  certFile = "/etc/traefik/tls/munchbox.pem"
  keyFile  = "/etc/traefik/tls/munchbox.pem"

[tls.stores]
  [tls.stores.default.defaultCertificate]
    certFile = "/etc/traefik/tls/munchbox.pem"
    keyFile  = "/etc/traefik/tls/munchbox.pem"

[tls.options]
  [tls.options.default]
    minVersion = "VersionTLS12"
    sniStrict  = true
    curvePreferences = ["CurveP521", "CurveP384"]
    cipherSuites = [
      "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
      "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256",
      "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
    ]

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

  # --- Traefik Dashboard (HTTPS, LAN-only) ---
  [http.routers.traefik-dashboard]
    rule        = "Host(`traefik.munchbox.cc`)"
    entryPoints = ["websecure"]
    service     = "api@internal"
    middlewares = ["dashboard-allowlan", "dashboard-auth", "dashboard-redirect"]
    [http.routers.traefik-dashboard.tls]

  # --- Traefik Dashboard fallback on :8081 ---
  [http.routers.traefik-fallback]
    rule        = "PathPrefix(`/dashboard`) || PathPrefix(`/api`)"
    entryPoints = ["traefik"]
    service     = "api@internal"
    middlewares = ["dashboard-allowlan", "dashboard-auth"]
    priority    = 2

  # --- Health check endpoint (no auth) ---
  [http.routers.ping]
    rule        = "Host(`traefik.munchbox.cc`) && Path(`/ping`)"
    entryPoints = ["websecure"]
    service     = "ping@internal"
    [http.routers.ping.tls]

  # --- Resume public (Cloudflare Tunnel) ---
  [http.routers.resume-public]
    rule        = "Host(`resume.alexfreidah.com`) || Host(`www.resume.alexfreidah.com`)"
    entryPoints = ["web"]
    service     = "nginx-resume"
    middlewares = ["redirect-resume-www", "resume-sec", "resume-ratelimit"]
    priority    = 100

  # --- Apex domain redirect ---
  [http.routers.resume-apex]
    rule        = "Host(`alexfreidah.com`) || Host(`www.alexfreidah.com`)"
    entryPoints = ["web"]
    service     = "nginx-resume"
    middlewares = ["redirect-apex-to-resume", "resume-sec"]
    priority    = 101

  # --- k3s-status public (Cloudflare Tunnel) ---
  [http.routers.k3s-status-public]
    rule        = "Host(`k3s-status.alexfreidah.com`)"
    entryPoints = ["web"]
    service     = "health-checker-svc"
    middlewares = ["k3s-status-sec"]
    priority    = 102

# -------------------------------------------------------------------------
# HTTP Middlewares
# -------------------------------------------------------------------------

[http.middlewares]

  # --- HTTPS redirect ---
  [http.middlewares.redirect-https.redirectScheme]
    scheme    = "https"
    permanent = true

  # --- LAN-only access ---
  [http.middlewares.dashboard-allowlan.ipAllowList]
    sourceRange = ["192.168.68.0/24", "127.0.0.1/32"]

  # --- Dashboard authentication ---
  [http.middlewares.dashboard-auth.basicAuth]
    users = ["alex:$2y$05$2pwj9TDZZ29xWxv.eUAKLeKOhm/RrbbrbNewMkzjg1aGm4Bp81yKS"]

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
    contentSecurityPolicy   = "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; frame-ancestors 'self'"

  # --- k3s-status security headers ---
  [http.middlewares.k3s-status-sec.headers]
    stsSeconds              = 31536000
    stsIncludeSubdomains    = true
    forceSTSHeader          = true
    contentTypeNosniff      = true
    customFrameOptionsValue = "SAMEORIGIN"
    referrerPolicy          = "no-referrer"
    contentSecurityPolicy   = "default-src 'self' data: blob: https:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval' blob:; connect-src 'self' https: ws: wss:; worker-src 'self' blob:; frame-ancestors 'self'"
    [http.middlewares.k3s-status-sec.headers.customResponseHeaders]
      Cache-Control = "no-store, no-cache, must-revalidate"

# -------------------------------------------------------------------------
# HTTP Services (non-Consul backends)
# -------------------------------------------------------------------------

[http.services]

  # --- Consul UI ---
  [http.services.consul-ui.loadBalancer]
    [[http.services.consul-ui.loadBalancer.servers]]
      url = "http://127.0.0.1:8500"

  # --- Resume backend (static IP until Consul-discovered) ---
  [http.services.nginx-resume.loadBalancer]
    [[http.services.nginx-resume.loadBalancer.servers]]
      url = "http://192.168.68.63:8080"

  # --- Health checker via Consul DNS ---
  [http.services.health-checker-svc.loadBalancer]
    [[http.services.health-checker-svc.loadBalancer.servers]]
      url = "http://health-checker.service.consul:18080"
EOH
      }

      # --- Service Registration (HTTPS) ---
      service {
        name     = "traefik"
        port     = "https"
        provider = "consul"
        tags     = ["traefik.enable=false", "metrics_port=8081"]

        check {
          name     = "traefik-https"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
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
