# -----------------------------------------------------------------------------
# Traefik Nomad Job
# -----------------------------------------------------------------------------
# This Nomad job definition runs Traefik as a system service on all nodes
# with the "ingress" role. It exposes HTTP, HTTPS, and the Traefik dashboard.
# Configuration files are templated and mounted into the container.
# This version is updated to route the dashboard under /traefik and
# supports path-based routing for other services (e.g., /grafana, /nomad).
# -----------------------------------------------------------------------------

job "traefik" {

  # Nomad region and datacenter configuration
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "system"

  # Only run on nodes with meta.role = "ingress"
  constraint {
    attribute = "${meta.role}"
    value     = "ingress"
    operator  = "="
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
        image = "traefik:v2.11"
        ports = [
          "http",
          "https",
          "dashboard"
        ]
        # Mount static and dynamic configuration files
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/traefik_dynamic.toml:/etc/traefik/traefik_dynamic.toml"
        ]
      }

      # Generate the main Traefik static configuration
      template {
        data = <<EOF
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

[ping]
  entryPoint    = "traefik"
  manualrouting = false

[providers.consulCatalog]
  prefix           = "traefik"
  exposedByDefault = false
  [providers.consulCatalog.endpoint]
    address = "127.0.0.1:8500"
    scheme  = "http"

[providers.file]
  filename = "/etc/traefik/traefik_dynamic.toml"
EOF

        destination = "local/traefik.toml"
      }

      # Generate the dynamic configuration for routers and middlewares
      template {
        data = <<EOF
[http.routers.traefik-dashboard]
  rule        = "PathPrefix(`/traefik`) || PathPrefix(`/api`)"
  entryPoints = ["web"]
  service     = "api@internal"
  middlewares = ["dashboard-auth", "dashboard-allowlan", "traefik-stripprefix"]

[http.middlewares.dashboard-auth.basicAuth]
  users = ["alex:$2y$05$2pwj9TDZZ29xWxv.eUAKLeKOhm/RrbbrbNewMkzjg1aGm4Bp81yKS"]

[http.middlewares.dashboard-allowlan.ipWhiteList]
  sourceRange = ["192.168.68.0/24"]

[http.middlewares.traefik-stripprefix.stripPrefix]
  prefixes = ["/traefik"]

[http.routers.consul]
  rule = "Host(`consul.munchbox`)"
  entryPoints = ["web"]
  service = "consul"

[http.services.consul.loadBalancer]
  [[http.services.consul.loadBalancer.servers]]
    url = "http://localhost:8500"

[http.routers.nomad]
  rule = "PathPrefix(`/nomad`)"
  entryPoints = ["web"]
  service = "nomad"
  middlewares = ["nomad-stripprefix"]

[http.services.nomad.loadBalancer]
  [[http.services.nomad.loadBalancer.servers]]
    url = "http://localhost:4646"

[http.middlewares.nomad-stripprefix.stripPrefix]
  prefixes = ["/nomad"]
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
