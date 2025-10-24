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
#   - http(s)://k3s-status.alexfreidah.com -> Cloudflare Tunnel -> Traefik (HTTP :80 locally)
#                                            -> health-checker via Consul DNS
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

  constraint {
    attribute = "$${meta.role}"
    operator  = "="
    value     = "ingress"
  }

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
        perms       = "0755"
        data        = <<EOT
<<INJECT:files/generate-certs.sh>>
EOT
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "traefik" {
      driver = "docker"

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

      template {
        destination = "secrets/consul.env"
        env         = true
        data        = <<EOT
<<INJECT:files/consul.env.ctmpl>>
EOT
      }

      template {
        destination = "local/traefik.toml"
        perms       = "0644"
        data        = <<EOT
<<INJECT:files/traefik.toml.ctmpl>>
EOT
      }

      template {
        destination = "local/traefik_dynamic.toml"
        change_mode = "restart"
        perms       = "0644"
        data        = <<EOT
<<INJECT:files/traefik_dynamic.toml.ctmpl>>
EOT
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "traefik"
        port = "https"
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
