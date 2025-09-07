# ------------------------------------------------------------------------------
# Cloudflare Tunnel — publish resume.alexfreidah.com to local Traefik
# ------------------------------------------------------------------------------
# Requirements:
#   1) Create a Tunnel in Cloudflare Zero Trust; obtain TUNNEL_UUID and
#      credentials JSON (cloudflared will generate it on auth).
#   2) Store the credentials JSON and config YAML in Consul KV, or replace the
#      template blocks with file mounts.
#   3) This runs on the same ingress node(s) as Traefik.
# ------------------------------------------------------------------------------
job "cloudflared-tunnel" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "system"

  # Only on ingress nodes
  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  group "cloudflared" {
    network {
      mode = "host"   # not strictly required; no inbound ports needed
    }

    task "cloudflared" {
      driver = "docker"

      config {
        image = "cloudflare/cloudflared:latest"

        args = [
          "tunnel",
          "--config", "/etc/cloudflared/config.yml",
          "--origincert", "/etc/cloudflared/credentials.json",
          "run"
        ]

        volumes = [
          "local/config.yml:/etc/cloudflared/config.yml:ro",
          "local/credentials.json:/etc/cloudflared/credentials.json:ro"
        ]
      }

      # Render config + credentials from your secret store
      template {
        destination = "local/credentials.json"
        data = <<-EOT
          {{ key "secrets/cloudflared/credentials.json" }}
        EOT
        change_mode = "restart"
        change_signal = "SIGTERM"
      }

      template {
        destination = "local/config.yml"
        data = <<-EOT
          tunnel: {{ key "secrets/cloudflared/tunnel_uuid" }}
          credentials-file: /etc/cloudflared/credentials.json
          ingress:
            - hostname: resume.alexfreidah.com
              service: http://127.0.0.1:80   # Traefik web entrypoint
            - service: http_status:404
        EOT
        change_mode = "restart"
        change_signal = "SIGTERM"
      }

      resources { cpu = 50 memory = 64 }

      # Optional: health check by hitting Traefik locally
      service {
        name = "cloudflared"
        port = "noop"
        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "curl -sSf http://127.0.0.1:80 >/dev/null"]
          interval = "30s"
          timeout  = "3s"
        }
      }
    }
  }
}

