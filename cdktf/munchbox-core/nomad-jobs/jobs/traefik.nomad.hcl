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
        data = <<EOF
[entryPoints]
  [entryPoints.web]
    address = ":80"
    [entryPoints.web.forwardedHeaders]
      # Trust forwarded headers from cloudflared (local connector)
      trustedIPs = ["127.0.0.1/32"]
  [entryPoints.websecure]
    address = ":443"
  [entryPoints.traefik]
    address = ":8081"

[api]
  dashboard = true
  insecure  = false

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
        change_mode = "restart"   # Operator-managed; restart task to re-render
        data = <<EOF
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

# --------------------------------------------------------------------
# Public hostname via Cloudflare Tunnel
# - cloudflared forwards resume.alexfreidah.com -> http://127.0.0.1:80
# - This router matches that Host header and points to the same backend.
# --------------------------------------------------------------------
[http.routers.resume-public]
  rule        = "Host(`resume.alexfreidah.com`,`www.resume.alexfreidah.com`)"
  entryPoints = ["web"]
  service     = "nginx-resume"

# --------------------------------------------------------------------
# Middlewares
# --------------------------------------------------------------------
[http.middlewares]

# Protect Traefik dashboard + restrict to LAN
[http.middlewares.dashboard-auth.basicAuth]
  users = ["alex:$2y$05$2pwj9TDZZ29xWxv.eUAKLeKOhm/RrbbrbNewMkzjg1aGm4Bp81yKS"]

[http.middlewares.dashboard-allowlan.ipWhiteList]
  sourceRange = ["192.168.68.0/24", "127.0.0.1/32"]  # allow local (cloudflared) too

[http.middlewares.redirect-resume-www.redirectRegex]
  regex       = "^https?://www\\.resume\\.alexfreidah\\.com/(.*)"
  replacement = "https://resume.alexfreidah.com/$1"
  permanent   = true

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
      }
      service {
        name = "traefik-dashboard"
        port = "dashboard"
      }
    }
  }
}
