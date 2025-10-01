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

      config {
        network_mode = "host"
        image        = "traefik:v3.5.3"
        ports        = ["http", "https", "dashboard"]

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/traefik_dynamic.toml:/etc/traefik/traefik_dynamic.toml"
        ]
      }

      # --- NEW: allow this task to read the Bao secret holding the Consul token -
      vault {
        policies = ["nomad-traefik-read"]
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
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# ============================================================================
# CONSUL CATALOG PROVIDER - Automatic Service Discovery
# ============================================================================
[providers.consulCatalog]
  refreshInterval = "15s"
  prefix          = "traefik"
  exposedByDefault = false

  [providers.consulCatalog.endpoint]
    address = "127.0.0.1:8500"
    # Token pulled from Bao/Vault (KV v2) at secret/infra/traefik
    token   = "{{ with secret "secret/data/infra/traefik" }}{{ .Data.data.consul_catalog_token }}{{ end }}"

# File provider drives our routers/services (rendered below)
[providers.file]
  filename = "/etc/traefik/traefik_dynamic.toml"

[accessLog]
[log]
  level = "INFO"
EOF
      }

      # -----------------------------------------------------------------------
      # Dynamic configuration (routers, middlewares, services)
      # - Switch internal routers to HTTPS (websecure) with TLS enabled.
      # - Add HTTP->HTTPS redirect for *.munchbox.
      # - Keep public Cloudflare-hosted router on HTTP (web) by design.
      # - Add /ping router on HTTPS that forwards to internal /ping handler.
      # - Add fallback dashboard router on :8081 (traefik entrypoint).
      # - TLS options configured here in v3.x (not in static config)
      # -----------------------------------------------------------------------
      template {
        destination = "local/traefik_dynamic.toml"
        change_mode = "restart" # Operator-managed; restart task to re-render
        data        = <<EOF
# --------------------------------------------------------------------
# Traefik Dynamic Config — HTTPS-first dashboards and services
# --------------------------------------------------------------------

# TLS certificate for *.munchbox (generated dynamically)
[[tls.certificates]]
  certFile = "/alloc/data/munchbox.crt"
  keyFile  = "/alloc/data/munchbox.key"

# TLS options (v3.x requires these in dynamic config, not static)
[tls.options]
  [tls.options.default]
    minVersion = "VersionTLS12"          # allow 1.2+; TLS 1.3 is auto-included
    sniStrict  = true
    curvePreferences = ["CurveP521", "CurveP384"]
    cipherSuites = [                      # applies to TLS 1.0–1.2 only
      "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
      "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256",
      "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
    ]

[http.routers]

# --------------------------------------------------------------------
# Internal dashboards (LAN only; now HTTPS)
# --------------------------------------------------------------------

# Traefik dashboard (HTTPS)
[http.routers.traefik]
  rule        = "Host(`traefik.munchbox`)"
  entryPoints = ["websecure"]
  service     = "api@internal"
  middlewares = ["dashboard-auth", "dashboard-allowlan", "dashboard-redirect"]
  [http.routers.traefik.tls]

# Fallback dashboard on :8081 (does not depend on TLS/certs)
[http.routers.traefik-fallback]
  rule        = "Host(`traefik.munchbox`) || PathPrefix(`/dashboard`) || PathPrefix(`/api`)"
  entryPoints = ["traefik"]
  service     = "api@internal"
  middlewares = ["dashboard-auth", "dashboard-allowlan", "dashboard-redirect"]
  priority    = 2

# --------------------------------------------------------------------
# Prometheus UI on HTTPS — file router pointing to consul-catalog backend
# (tiny shim to ensure Host(`prometheus.munchbox`) always resolves)
# --------------------------------------------------------------------
[http.routers.prometheus-ui]
  rule        = "Host(`prometheus.munchbox`)"
  entryPoints = ["websecure"]
  service     = "prometheus-svc"
  middlewares = ["dashboard-allowlan"]
  [http.routers.prometheus-ui.tls]

# --------------------------------------------------------------------
# Public hostname via Cloudflare Tunnel (HTTP locally by design)
# - cloudflared forwards resume.alexfreidah.com -> http://127.0.0.1:80
# - This router matches that Host header and points to the same backend.
# - Hardcoded backend (Consul discovery broken for this service)
# --------------------------------------------------------------------
[http.routers.resume-public]
  rule        = "Host(`resume.alexfreidah.com`) || Host(`www.resume.alexfreidah.com`)"
  entryPoints = ["web"]
  service     = "nginx-resume"
  middlewares = ["redirect-resume-www", "resume-sec", "resume-ratelimit", "resume-inflight"]
  priority    = 100

# --------------------------------------------------------------------
# Global HTTP -> HTTPS redirect for *.munchbox (keeps LAN tidy)
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
# Middlewares
# --------------------------------------------------------------------
[http.middlewares]

# Protect Traefik dashboard + restrict to LAN
[http.middlewares.dashboard-auth.basicAuth]
  users = ["alex:$2y$05$2pwj9TDZZ29xWxv.eUAKLeKOhm/RrbbrbNewMkzjg1aGm4Bp81yKS"]

[http.middlewares.dashboard-allowlan.ipAllowList]
  sourceRange = ["192.168.68.0/24", "127.0.0.1/32"]  # allow local (cloudflared) too

[http.middlewares.dashboard-redirect.redirectRegex]
  regex       = "^https?://traefik\\.munchbox/?$"
  replacement = "https://traefik.munchbox/dashboard/"
  permanent   = true

# HTTP -> HTTPS redirect
[http.middlewares.redirect-https.redirectScheme]
  scheme = "https"

# Per-IP token bucket (avg 20 r/s, burst 40)
[http.middlewares.resume-ratelimit.rateLimit]
  average = 20
  burst   = 40
  [http.middlewares.resume-ratelimit.rateLimit.sourceCriterion]
    requestHeaderName = "CF-Connecting-IP"

# --- COEP/COOP/CORP for cross-origin isolation on the resume host ---
[http.middlewares.resume-sec.headers.customResponseHeaders]
  Cross-Origin-Embedder-Policy = "unsafe-none"
  Cross-Origin-Opener-Policy   = "unsafe-none"
  Cross-Origin-Resource-Policy = "cross-origin"

# Global cap on concurrent requests reaching the backend
[http.middlewares.resume-inflight.inFlightReq]
  amount = 100

# Redirect www.resume -> apex
[http.middlewares.redirect-resume-www.redirectRegex]
  regex       = "^https?://www\\.resume\\.alexfreidah\\.com/(.*)"
  replacement = "https://resume.alexfreidah.com/$1"
  permanent   = true

# Resume security headers (HSTS, XFO, nosniff, Referrer-Policy, Permissions-Policy, CSP)
[http.middlewares.resume-sec.headers]
  # --- HSTS ---
  stsSeconds           = 31536000
  stsIncludeSubdomains = true
  forceSTSHeader       = true
  # Only set true if you intend to submit to the preload list and ALL subdomains are HTTPS
  stsPreload           = false

  # --- Classic hardening ---
  contentTypeNosniff       = true
  customFrameOptionsValue  = "SAMEORIGIN"
  referrerPolicy           = "no-referrer"

  # --- Permissions-Policy: disable sensitive features by default ---
  permissionsPolicy = """
    geolocation=(), microphone=(), camera=(), usb=(),
    fullscreen=(self), payment=(), accelerometer=(),
    gyroscope=(), magnetometer=(), midi=(),
    picture-in-picture=(), clipboard-read=(), clipboard-write=(),
    browsing-topics=()
  """

  # --- CSP: allow inline scripts so the theme boot/toggle works; keep tight otherwise ---
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
# Services (backends)
# --------------------------------------------------------------------
[http.services]

# Resume backend - hardcoded since Consul discovery is broken for this service
[http.services.nginx-resume.loadBalancer]
  [[http.services.nginx-resume.loadBalancer.servers]]
    url = "http://192.168.68.63:8080"

# Prometheus backend (host network on node "stabler")
[http.services."prometheus-svc".loadBalancer]
  [[http.services."prometheus-svc".loadBalancer.servers]]
    url = "http://192.168.68.61:9090"

# Health forwarder for HTTPS /ping router (fronts the internal /ping ep)
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
