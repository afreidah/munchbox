# -----------------------------------------------------------------------------
# Traefik Nomad Job
# -----------------------------------------------------------------------------
# Purpose:
#   - Run Traefik as a system service on ingress nodes.
#   - Expose HTTP (:80) for local/LAN access and for Cloudflare Tunnel egress
#     (cloudflared -> http://127.0.0.1:80 -> Traefik).
#   - Expose the Traefik dashboard on :8081 (LAN-restricted).
#
# Host-based routing summary:
#   - http://traefik.munchbox          -> Traefik dashboard (LAN only)
#   - http://consul.munchbox           -> Consul UI (on this node)
#   - http://nomad.munchbox            -> Nomad UI (Hashi-UI on this node)
#   - http://grafana.munchbox          -> Grafana UI (remote node)
#   - http://registry.munchbox         -> Docker Registry UI (remote node)
#   - http://resume.munchbox           -> Local resume site (on mccoy:8080)
#   - https://resume.alexfreidah.com   -> Public resume site via Cloudflare
#                                         Tunnel -> Traefik -> nginx-resume
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

    task "traefik" {
      driver = "docker"

      config {
        network_mode = "host"
        image        = "traefik:v2.11"
        ports        = ["http", "https", "dashboard"]
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/traefik_dynamic.toml:/etc/traefik/traefik_dynamic.toml"
        ]
      }

      # -----------------------------------------------------------------------
      # Static configuration
      # - Entrypoints: web (:80), websecure (:443), traefik (:8081)
      # - Providers: file (dynamic TOML rendered below)
      # - Forwarded headers: trust 127.0.0.1 so Traefik honors X-Forwarded-For
      #   / Forwarded headers coming from cloudflared (which connects from
      #   localhost) when using Cloudflare Tunnel.
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
		[entryPoints.websecure.http.tls]
    	options = "modern@file"
    [entryPoints.websecure.forwardedHeaders] 
      trustedIPs = ["127.0.0.1/32"] 

  [entryPoints.traefik]
    address = ":8081"

[tls.options]
  [tls.options.modern]
    minVersion = "VersionTLS12"          # allow 1.2+; TLS 1.3 is auto-included
    sniStrict  = true
    curvePreferences = ["CurveP521", "CurveP384"]
    cipherSuites = [                      # applies to TLS 1.0–1.2 only
      "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
      "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
      "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
    ]
    disableSessionTickets = true          # full handshakes; no resumption tickets

[api]
  dashboard = true
  insecure  = false

[ping]                                             
  entryPoint = "traefik"                          

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
      # - Adds a *public* router for resume.alexfreidah.com (Cloudflare Tunnel)
      #   pointing to the same backend as the local resume.munchbox router.
      # -----------------------------------------------------------------------
      template {
        destination = "local/traefik_dynamic.toml"
        change_mode = "restart" # Operator-managed; restart task to re-render
        data        = <<EOF
# --------------------------------------------------------------------
# Traefik Dynamic Config — subdomain-based dashboards and services
# --------------------------------------------------------------------

[http.routers]

# --------------------------------------------------------------------
# Internal dashboards (LAN only)
# --------------------------------------------------------------------

# Traefik dashboard
[http.routers.traefik]
  rule        = "Host(`traefik.munchbox`)"
  entryPoints = ["web"]
  service     = "api@internal"
  middlewares = ["dashboard-auth", "dashboard-allowlan"]

# Consul UI (Consul runs on this ingress node)
[http.routers.consul]
  rule        = "Host(`consul.munchbox`)"
  entryPoints = ["web"]
  service     = "consul"

# Nomad UI (Hashi-UI web interface)
[http.routers.nomad]
  rule        = "Host(`nomad.munchbox`)"
  entryPoints = ["web"]
  service     = "hashiui"

# --------------------------------------------------------------------
# Internal apps (LAN hostnames)
# --------------------------------------------------------------------

# Deluge Web UI (runs on stabler)
[http.routers.deluge]
  rule        = "Host(`deluge.munchbox`)"
  entryPoints = ["web"]
  service     = "deluge"

# Grafana UI (REMOTE node — set the IP below)
[http.routers.grafana]
  rule        = "Host(`grafana.munchbox`)"
  entryPoints = ["web"]
  service     = "grafana"

# Gitlab 
[http.routers.gitlab]
  rule        = "Host(`gitlab.munchbox`)"
  entryPoints = ["web"]
  service     = "gitlab"

# Docker Registry UI (REMOTE node — set the IP below)
[http.routers.docker-registry-ui]
  rule        = "Host(`registry.munchbox`)"
  entryPoints = ["web"]
  service     = "docker-registry-ui"

# Resume Static Site (LAN hostname)
[http.routers.nginx-resume]
  rule        = "Host(`resume.munchbox`)"
  entryPoints = ["web"]
  service     = "nginx-resume"
  middlewares = ["resume-sec"]                       # ADDED

# --------------------------------------------------------------------
# Public hostname via Cloudflare Tunnel
# - cloudflared forwards resume.alexfreidah.com -> http://127.0.0.1:80
# - This router matches that Host header and points to the same backend.
# --------------------------------------------------------------------
[http.routers.resume-public]
  rule        = "Host(`resume.alexfreidah.com`,`www.resume.alexfreidah.com`)"
  entryPoints = ["web"]
  service     = "nginx-resume"
  middlewares = ["redirect-resume-www", "resume-sec", "resume-ratelimit", "resume-inflight"]

# --------------------------------------------------------------------
# Traefik Dynamic Config — Middlewares
# --------------------------------------------------------------------
[http.middlewares]

# Protect Traefik dashboard + restrict to LAN
[http.middlewares.dashboard-auth.basicAuth]
  users = ["alex:$2y$05$2pwj9TDZZ29xWxv.eUAKLeKOhm/RrbbrbNewMkzjg1aGm4Bp81yKS"]

[http.middlewares.dashboard-allowlan.ipWhiteList]
  sourceRange = ["192.168.68.0/24", "127.0.0.1/32"]  # allow local (cloudflared) too

# Per-IP token bucket (avg 20 r/s, burst 40)
[http.middlewares.resume-ratelimit.rateLimit]
  average = 20
  burst   = 40
  [http.middlewares.resume-ratelimit.rateLimit.sourceCriterion]
    requestHeaderName = "CF-Connecting-IP"

# --- COEP/COOP/CORP for cross-origin isolation on the resume host ---
[http.middlewares.resume-sec.headers.customResponseHeaders]
  Cross-Origin-Embedder-Policy = "require-corp"  # or "credentialless" (see notes)
  Cross-Origin-Opener-Policy   = "same-origin"
  Cross-Origin-Resource-Policy = "same-origin"

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

# Backends on THIS host for Consul
[http.services.consul.loadBalancer]
  [[http.services.consul.loadBalancer.servers]]
    url = "http://127.0.0.1:8500"

# Hashi-UI (Nomad UI) backend
[http.services.hashiui.loadBalancer]
  [[http.services.hashiui.loadBalancer.servers]]
    url = "http://127.0.0.1:3000"

# Deluge Web UI backend (runs on stabler)
[http.services.deluge.loadBalancer]
  [[http.services.deluge.loadBalancer.servers]]
    url = "http://mccoy:8112"

# Grafana runs on a different node: REPLACE cabot below
[http.services.grafana.loadBalancer]
  [[http.services.grafana.loadBalancer.servers]]
    url = "http://cabot:3000"

# Gitlab 
[http.services.gitlab.loadBalancer]
  [[http.services.gitlab.loadBalancer.servers]]
    url = "http://cabot:8080"

# Registry-UI
[http.services.docker-registry-ui.loadBalancer]
  [[http.services.docker-registry-ui.loadBalancer.servers]]
    url = "http://goren:5001"

# Resume Static Page
# NOTE: The resume job is pinned to host 'mccoy' with host port 8080 in its group.
[http.services.nginx-resume.loadBalancer]
  [[http.services.nginx-resume.loadBalancer.servers]]
    url = "http://192.168.68.63:8080"
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
        check {                  # ADDED
          name     = "tcp-https" # ADDED
          type     = "tcp"       # ADDED
          interval = "10s"       # ADDED
          timeout  = "2s"        # ADDED
        }                        # ADDED
      }
      service {
        name = "traefik-dashboard"
        port = "dashboard"
        check {                  # ADDED
          name     = "http-ping" # ADDED
          type     = "http"      # ADDED
          path     = "/ping"     # ADDED 
          interval = "10s"       # ADDED
          timeout  = "2s"        # ADDED
        }                        # ADDED
      }
    }
  }
}
