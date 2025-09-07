# -----------------------------------------------------------------------------
# Traefik Nomad Job
# -----------------------------------------------------------------------------
# Runs Traefik as a system service on ingress nodes, exposes HTTP and dashboard.
# Uses host-based routing:
#   - http://traefik.munchbox  -> Traefik dashboard
#   - http://consul.munchbox   -> Consul UI  (on this node)
#   - http://nomad.munchbox    -> Nomad UI   (on this node)
#   - http://grafana.munchbox  -> Grafana UI (on remote node IP below)
# -----------------------------------------------------------------------------

job "traefik" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "system"

  # Only run on nodes with meta.role = "ingress"
  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  group "traefik" {

    # Host networking exposes ports directly on the host
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

      # ---------------------------------------------------------------------------
      # Static configuration (entrypoints + file provider only)
      # ---------------------------------------------------------------------------
      template {
        data        = <<EOF
[entryPoints]
  [entryPoints.web]
    address = ":80"
  [entryPoints.websecure]
    address = ":443"
  [entryPoints.traefik]
    address = ":8081"

[api]
  dashboard = true
  insecure  = false

# File provider drives our routers/services
[providers.file]
  filename = "/etc/traefik/traefik_dynamic.toml"

[accessLog]
[log]
  level = "INFO"
EOF
        destination = "local/traefik.toml"
      }

      # ---------------------------------------------------------------------------
      # Dynamic configuration (routers, middlewares, services)
      # ---------------------------------------------------------------------------
      template {
        data        = <<EOF
# --------------------------------------------------------------------
# Traefik Dynamic Config — subdomain-based dashboards
# --------------------------------------------------------------------

[http.routers]

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

# Gitlab UI (REMOTE node — set the IP below)
[http.routers.gitlab]
  rule        = "Host(`gitlab.munchbox`)"
  entryPoints = ["web"]
  service     = "gitlab"

# Docker Registry UI (REMOTE node — set the IP below)
[http.routers.docker-registry-ui]
  rule        = "Host(`registry.munchbox`)"
  entryPoints = ["web"]
  service     = "docker-registry-ui"

# Resume Static Site Router
[http.routers.nginx-resume]
  rule        = "Host(`resume.munchbox`)"
  entryPoints = ["web"]
  service     = "nginx-resume"

[http.middlewares]
# Protect Traefik dashboard + restrict to LAN
[http.middlewares.dashboard-auth.basicAuth]
  users = ["alex:$2y$05$2pwj9TDZZ29xWxv.eUAKLeKOhm/RrbbrbNewMkzjg1aGm4Bp81yKS"]

[http.middlewares.dashboard-allowlan.ipWhiteList]
  sourceRange = ["192.168.68.0/24"]

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
[http.services.nginx-resume.loadBalancer]
  [[http.services.nginx-resume.loadBalancer.servers]]
    url = "http://mccoy:8080"
EOF
        destination = "local/traefik_dynamic.toml"
        change_mode = "noop"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      # Register Traefik services for service discovery
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
