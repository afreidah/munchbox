# ------------------------------------------------------------------------------
# Cloudflare Tunnel (cloudflared) — File-mode with YAML config
# ------------------------------------------------------------------------------
# What this does
# - Runs cloudflared as a system job on ingress nodes.
# - Uses *host networking* so 127.0.0.1:80 inside the container reaches Traefik
#   on the host. This fixes “Unable to reach the origin service 127.0.0.1:80”.
# - Renders both the credentials and the config *via Nomad templates* into
#   /local, and bind-mounts them into /etc/cloudflared in the container.
# - Ingress includes BOTH:
#       resume.alexfreidah.com
#       www.resume.alexfreidah.com
#   so either hostname works.
#
# Requirements (already satisfied in your setup):
# - Consul KV keys:
#     secrets/cloudflared/credentials.json  (full JSON from `cloudflared tunnel create`)
#     secrets/cloudflared/tunnel_uuid       (UUID of the tunnel)
# - Traefik is listening on host :80 and serves your resume routes.
# - A DNS route for each hostname (create with `cloudflared tunnel route dns ...`).
# ------------------------------------------------------------------------------

job "cloudflared-tunnel" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "system"

  # Only run on nodes that act as ingress
  # If you paste this into Terraform/CDKTF, escape as $${meta.role}
  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  group "cloudflared" {
    # Host networking so 127.0.0.1 inside the container = host network namespace
    network { mode = "host" }

    task "cloudflared" {
      driver = "docker"

      config {
        image        = "cloudflare/cloudflared:latest"
        # Host net mode inside Docker as well (belt-and-suspenders)
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
      }

      # ---- credentials.json (rendered from Consul KV) -----------------------
      # NOTE: Do not indent YAML in heredocs; keep column 0 to avoid stray
      #       spaces/tabs that can break parsing when templates render.
      template {
        destination   = "local/credentials.json"
        change_mode   = "restart"
        change_signal = "SIGTERM"
        data = <<EOF
{{ key "secrets/cloudflared/credentials.json" }}
EOF
      }

      # ---- config.yml (rendered from Consul KV + static ingress) ------------
      # IMPORTANT:
      # - Heredoc starts at column 0 (no leading spaces).
      # - YAML uses spaces only (no tabs).
      # - Both hostnames are included.
      template {
        destination   = "local/config.yml"
        change_mode   = "restart"
        change_signal = "SIGTERM"
        data = <<EOF
tunnel: {{ key "secrets/cloudflared/tunnel_uuid" }}
credentials-file: /etc/cloudflared/credentials.json
ingress:
  - hostname: "resume.alexfreidah.com"
    service: http://127.0.0.1:80
  - hostname: "www.resume.alexfreidah.com"
    service: http://127.0.0.1:80
  - service: http_status:404
EOF
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
