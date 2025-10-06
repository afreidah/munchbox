# -----------------------------------------------------------------------------
# Traefik Nomad Job — HTTPS-first (with HTTP redirect & /ping on HTTPS)
# -----------------------------------------------------------------------------
# Purpose:
#   - Run Traefik as a system service on ingress nodes.
#   - Expose HTTP (:80) and HTTPS (:443). HTTP is used for redirect-to-HTTPS
#     and to accept Cloudflare Tunnel traffic locally (cloudflared -> http:80).
#   - Expose the Traefik dashboard on :8081 (LAN-restricted).
#
# Host-based routing summary:
#   - https://traefik.munchbox         -> Traefik dashboard (LAN only; auth)
#   - https://consul.munchbox          -> Consul UI (on this node)
#   - https://nomad.munchbox           -> Nomad UI (Hashi-UI on this node)
#   - https://grafana.munchbox         -> Grafana UI (remote node)
#   - https://registry.munchbox        -> Docker Registry UI (remote node)
#   - https://resume.munchbox          -> Local resume site (on mccoy:8080), via HTTPS
#   - https://resume.alexfreidah.com   -> Public resume site via Cloudflare
#                                         Tunnel -> Traefik (HTTP :80 locally) -> nginx-resume
#
# Notes:
#   - HTTP (:80) remains enabled. All *.munchbox requests on HTTP redirect to HTTPS,
#     except the Cloudflare public host router which intentionally stays on HTTP.
#   - A no-auth /ping is exposed on HTTPS for monitoring (blackbox probe).
#   - Self-signed certificates for *.munchbox are generated automatically on first start.
#   - Services auto-discovered via Consul Catalog with traefik.enable=true tags
# -----------------------------------------------------------------------------

job "traefik" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "system"

  # ---------------------------------------------------------------------------
  # Placement: only run on nodes with meta.role = "ingress"
  # NOTE: If you run this jobspec via Terraform/CDKTF nomad_job, escape as
  #       $${meta.role} in that context to avoid TF interpolation.
  # ---------------------------------------------------------------------------
  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  # ---------------------------------------------------------------------------
  # Update strategy: ensure zero-downtime deployments
  # - Canary deployment tests new version before full rollout
  # - Auto-promote only after health checks pass
  # - Auto-revert on any failure
  # ---------------------------------------------------------------------------
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
  }

  group "traefik" {

    # -------------------------------------------------------------------------
    # Networking: host mode so Traefik binds directly on the node
    # -------------------------------------------------------------------------
    network {
      mode = "host"

      port "dashboard" {
        static = 8081
        to     = 8081
      }

      port "http" {
        static = 80
        to     = 80
      }

      port "https" {
        static = 443
        to     = 443
      }
    }

    # -------------------------------------------------------------------------
    # Prestart task: generate self-signed certificates before Traefik starts
    # -------------------------------------------------------------------------
    task "certgen" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "alpine:latest"
        command = "sh"
        args    = ["-c", "apk add --no-cache openssl && /local/generate-certs.sh"]
      }

      template {
        destination = "local/generate-certs.sh"
        perms       = "755"
        data        = <<EOF
#!/bin/sh
set -e

# Use /alloc/data which is shared between all tasks in the group
CERT_DIR=/alloc/data

# Check if valid certificates exist by actually validating them
if [ -f $CERT_DIR/munchbox.crt ] && [ -f $CERT_DIR/munchbox.key ]; then
  if openssl x509 -in $CERT_DIR/munchbox.crt -noout 2>/dev/null; then
    echo "Valid certificates already exist, skipping generation"
    exit 0
  else
    echo "Invalid certificates found, regenerating..."
    rm -f $CERT_DIR/munchbox.crt $CERT_DIR/munchbox.key
  fi
fi

echo "Generating self-signed certificate for *.munchbox..."
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout $CERT_DIR/munchbox.key \
  -out $CERT_DIR/munchbox.crt \
  -days 3650 \
  -subj "/CN=*.munchbox" \
  -addext "subjectAltName=DNS:*.munchbox,DNS:munchbox"

echo "Certificate generated successfully"
ls -la $CERT_DIR/munchbox.*

# Verify the certificates are valid PEM format
echo "Verifying certificate..."
openssl x509 -in $CERT_DIR/munchbox.crt -text -noout | head -5
EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "traefik" {
      driver = "docker"

      # -----------------------------------------------------------------------
      # Vault Workload Identity integration for pulling Consul token
      # -----------------------------------------------------------------------
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      vault {
        role = "nomad-workloads"
      }

      config {
        network_mode = "host"
        image        = "traefik:v3.5.3"
        ports        = ["http", "https", "dashboard"]

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/traefik_dynamic.toml:/etc/traefik/traefik_dynamic.toml"
        ]
      }

      # -----------------------------------------------------------------------
      # Pull Consul token from Vault
      # -----------------------------------------------------------------------
      template {
        destination = "secrets/consul.env"
        env         = true
        data        = <<EOH
{{ with secret "kv/data/traefik" }}
CONSUL_TOKEN={{ .Data.data.consul_token }}
{{ end }}
EOH
      }

      # -----------------------------------------------------------------------
      # Static configuration
      # - Entrypoints: web (:80), websecure (:443), traefik (:8081)
      # - Providers: Consul Catalog (dynamic discovery) + file (static overrides)
      # - Forwarded headers: trust 127.0.0.1 so Traefik honors X-Forwarded-For
      #   / Forwarded headers coming from cloudflared (which connects from
      #   localhost) when using Cloudflare Tunnel.
      # - TLS options moved to dynamic config in v3.x
      # -----------------------------------------------------------------------
      template {
        destination = "local/traefik.toml"
        data        = <<EOF
[entryPoints]
  [entryPoints.web]
    address = ":80"
    [entryPoints.web.forwardedHeaders]
      # Trust forwarded headers from cloudflared (local connector)
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
  entryPoint = "traefik"                  # Internal handler; HTTPS router forwards to it

# >>>>>>>>>>>>>>>>>>>>>>>>>>>> Prometheus metrics >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
[metrics]
  [metrics.prometheus]
    entryPoint             = "traefik"
    addEntryPointsLabels   = true
    addServicesLabels      = true
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# ============================================================================
# CONSUL CATALOG PROVIDER - Automatic Service Discovery
# ============================================================================
[providers.consulCatalog]
  refreshInterval = "15s"
  prefix          = "traefik"
  exposedByDefault = false

  [providers.consulCatalog.endpoint]
    address = "127.0.0.1:8500"
    # Token pulled from Vault via environment variable
    token = "{{ env "CONSUL_TOKEN" }}"

# File provider drives our routers/services (rendered below)
[providers.file]
  filename = "/etc/traefik/traefik_dynamic.toml"

[accessLog]
[log]
  level = "INFO"
EOF
      }

      # -----------------------------------------------------------------------
      # Dynamic configuration - MINIMAL (Consul-first approach)
      # Only defines:
      #   - TLS certificates
      #   - Global middlewares (auth, IP allowlist, security headers)
      #   - Static routes that can't use Consul (resume public, ping, dashboard)
      # Everything else discovered via Consul Catalog Provider
      # -----------------------------------------------------------------------
      template {
        destination = "local/traefik_dynamic.toml"
        change_mode = "restart"
        data        = <<EOF
# --------------------------------------------------------------------
# Traefik Dynamic Config — Consul-First Approach
# All services discovered via Consul Catalog except static routes below
# --------------------------------------------------------------------

# TLS certificate for *.munchbox (generated dynamically)
[[tls.certificates]]
  certFile = "/alloc/data/munchbox.crt"
  keyFile  = "/alloc/data/munchbox.key"

# Default TLS store certificate (covers unknown SNI / direct-IP)
[tls.stores]
  [tls.stores.default.defaultCertificate]
    certFile = "/alloc/data/munchbox.crt"
    keyFile  = "/alloc/data/munchbox.key"

# TLS options (v3.x requires these in dynamic config, not static)
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

[http.routers]

# --------------------------------------------------------------------
# Traefik dashboard fallback on :8081 (does not depend on TLS/certs)
# --------------------------------------------------------------------
[http.routers.traefik-fallback]
  rule        = "Host(`traefik.munchbox`) || PathPrefix(`/dashboard`) || PathPrefix(`/api`)"
  entryPoints = ["traefik"]
  service     = "api@internal"
  middlewares = ["dashboard-auth", "dashboard-allowlan", "dashboard-redirect"]
  priority    = 2

# --------------------------------------------------------------------
# Public hostname via Cloudflare Tunnel (HTTP locally by design)
# --------------------------------------------------------------------
[http.routers.resume-public]
  rule        = "Host(`resume.alexfreidah.com`) || Host(`www.resume.alexfreidah.com`)"
  entryPoints = ["web"]
  service     = "nginx-resume"
  middlewares = ["redirect-resume-www", "resume-sec", "resume-ratelimit", "resume-inflight"]
  priority    = 100

# --------------------------------------------------------------------
# Global HTTP -> HTTPS redirect for *.munchbox
# --------------------------------------------------------------------
[http.routers.http-redirect]
  rule        = "HostRegexp(`{host:.+\\.munchbox}`)"
  entryPoints = ["web"]
  middlewares = ["redirect-https"]
  service     = "ping-svc"
  priority    = 1

# Health router: no auth, HTTPS, fronts internal /ping handler
[http.routers.ping]
  rule        = "Host(`traefik.munchbox`) && Path(`/ping`)"
  entryPoints = ["websecure"]
  service     = "ping-svc"
  [http.routers.ping.tls]

# --------------------------------------------------------------------
# Middlewares (shared by both file and Consul-discovered routers)
# --------------------------------------------------------------------
[http.middlewares]

# Dashboard authentication
[http.middlewares.dashboard-auth.basicAuth]
  users = ["alex:$2y$05$2pwj9TDZZ29xWxv.eUAKLeKOhm/RrbbrbNewMkzjg1aGm4Bp81yKS"]

# LAN-only access (used by all internal dashboards via @file reference)
[http.middlewares.dashboard-allowlan.ipAllowList]
  sourceRange = ["192.168.68.0/24", "127.0.0.1/32"]

[http.middlewares.dashboard-redirect.redirectRegex]
  regex       = "^https?://traefik\\.munchbox/?$"
  replacement = "https://traefik.munchbox/dashboard/"
  permanent   = true

# HTTP -> HTTPS redirect
[http.middlewares.redirect-https.redirectScheme]
  scheme = "https"

# Resume rate limiting
[http.middlewares.resume-ratelimit.rateLimit]
  average = 20
  burst   = 40
  [http.middlewares.resume-ratelimit.rateLimit.sourceCriterion]
    requestHeaderName = "CF-Connecting-IP"

# Resume CORS headers
[http.middlewares.resume-sec.headers.customResponseHeaders]
  Cross-Origin-Embedder-Policy = "unsafe-none"
  Cross-Origin-Opener-Policy   = "unsafe-none"
  Cross-Origin-Resource-Policy = "cross-origin"

[http.middlewares.resume-inflight.inFlightReq]
  amount = 100

# Redirect www.resume -> apex
[http.middlewares.redirect-resume-www.redirectRegex]
  regex       = "^https?://www\\.resume\\.alexfreidah\\.com/(.*)"
  replacement = "https://resume.alexfreidah.com/$1"
  permanent   = true

# Resume security headers (HSTS, XFO, nosniff, Referrer-Policy, Permissions-Policy, CSP)
[http.middlewares.resume-sec.headers]
  stsSeconds           = 31536000
  stsIncludeSubdomains = true
  forceSTSHeader       = true
  stsPreload           = false
  contentTypeNosniff       = true
  customFrameOptionsValue  = "SAMEORIGIN"
  referrerPolicy           = "no-referrer"
  permissionsPolicy = """
    geolocation=(), microphone=(), camera=(), usb=(),
    fullscreen=(self), payment=(), accelerometer=(),
    gyroscope=(), magnetometer=(), midi=(),
    picture-in-picture=(), clipboard-read=(), clipboard-write=(),
    browsing-topics=()
  """
  contentSecurityPolicy = """
    default-src 'self';
    base-uri 'self';
    object-src 'none';
    frame-ancestors 'self';
    img-src 'self' data: blob:;
    font-src 'self' data:;
    style-src 'self' 'unsafe-inline';
    script-src 'self' 'unsafe-inline';
    connect-src 'none';
    form-action 'self';
    upgrade-insecure-requests;
  """

# --------------------------------------------------------------------
# Services (only for non-Consul backends)
# --------------------------------------------------------------------
[http.services]

# Resume backend - points to nginx-resume service
[http.services.nginx-resume.loadBalancer]
  [[http.services.nginx-resume.loadBalancer.servers]]
    url = "http://192.168.68.63:8080"

# Health forwarder for HTTPS /ping router
[http.services.ping-svc.loadBalancer]
  [[http.services.ping-svc.loadBalancer.servers]]
    url = "http://127.0.0.1:8081/ping"
EOF
      }

      # -----------------------------------------------------------------------
      # Resources
      # -----------------------------------------------------------------------
      resources {
        cpu    = 200
        memory = 256
      }

      # -----------------------------------------------------------------------
      # Service registration (for observability / discovery as needed)
      # -----------------------------------------------------------------------
      service {
        name = "traefik"
        port = "https"
        # Surface metrics port as a tag for discovery flexibility
        tags = ["metrics_port=8081"]
        check {
          name     = "tcp-https"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
      service {
        name = "traefik-dashboard"
        port = "dashboard"
        check {
          name     = "http-ping"
          type     = "http"
          path     = "/ping"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
