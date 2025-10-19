# ------------------------------------------------------------------------------
# Cloudflare Tunnel (cloudflared) — File-mode with YAML config
# ------------------------------------------------------------------------------
# What this does
# - Runs cloudflared as a system job on the ingress node (mccoy only).
# - Uses *host networking* so connections originate from the host namespace.
# - Renders both the credentials and the config *via Nomad templates* into
#   /local, and bind-mounts them into /etc/cloudflared in the container.
# - Ingress includes BOTH:
#       alexfreidah.com
#       www.alexfreidah.com
#   so either hostname works.
#
# Requirements
# - Consul KV keys:
#     secrets/cloudflared/credentials.json  (full JSON from `cloudflared tunnel create`)
#     secrets/cloudflared/tunnel_uuid       (UUID of the tunnel)
# - Traefik is listening on host :80 and serves the resume routes.
# - A DNS route for each hostname (create with `cloudflared tunnel route dns ...`).
# TODO: automate the creation of tunnel and publish to consul, and the dns routes
# ------------------------------------------------------------------------------

job "cloudflared-tunnel" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "system"

  # Run only on the ingress node (mccoy)
  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }

  group "cloudflared" {
    # Host networking so the container sees the host network namespace
    network { mode = "host" }

    task "cloudflared" {
      driver = "docker"

      config {
        image        = "cloudflare/cloudflared:latest" # always use the newest container
        force_pull   = true                            # ensure we actually pull the latest on deploy
        network_mode = "host"

        # Use the mounted file-mode config
        args = [
          "tunnel",
          "--config", "/etc/cloudflared/config.yml",
          "run"
        ]

        # Bind the rendered templates into the container
        volumes = [
          "local/config.yml:/etc/cloudflared/config.yml:ro",
          "local/credentials.json:/etc/cloudflared/credentials.json:ro"
        ]

        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "cloudflared-tunnel"
          }
        }
      }

      # ---- credentials.json (rendered from Consul KV) -----------------------
      template {
        destination   = "local/credentials.json"
        change_mode   = "restart"
        change_signal = "SIGTERM"
        data          = <<EOF
{{ key "secrets/cloudflared/credentials.json" }}
EOF
      }

      # ---- config.yml (rendered from Consul KV + static ingress) ------------
      template {
        destination   = "local/config.yml"
        change_mode   = "restart"
        change_signal = "SIGTERM"
        data          = <<EOF
tunnel: {{ key "secrets/cloudflared/tunnel_uuid" }}
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: "alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: alexfreidah.com }

  - hostname: "www.alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: www.alexfreidah.com }

  - hostname: "resume.alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: resume.alexfreidah.com }

  - hostname: "k3s-status.alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: k3s-status.alexfreidah.com }

  - service: http_status:404

warp-routing:
  enabled: false
EOF
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
