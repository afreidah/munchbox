# ------------------------------------------------------------------------------
# Cloudflare Tunnel (cloudflared) — File-mode with YAML config
# ------------------------------------------------------------------------------
# What this does
# - Runs cloudflared as a system job on ingress nodes.
# - Uses *host networking* so 127.0.0.1:80 inside the container reaches Traefik
#   on the host.
# - Renders both the credentials and the config *via Nomad templates* into
#   /local, and bind-mounts them into /etc/cloudflared in the container.
# - Ingress includes BOTH:
#       resume.alexfreidah.com
#       www.resume.alexfreidah.com
#   so either hostname works.
#
# Requirements
# - Consul KV keys:
#     secrets/cloudflared/credentials.json  (full JSON from `cloudflared tunnel create`)
#     secrets/cloudflared/tunnel_uuid       (UUID of the tunnel)
# - Traefik is listening on host :80 and serves the resume routes.
# - A DNS route for each hostname (create with `cloudflared tunnel route dns ...`).
# TODO: automate the creation of tunnel and publish to consul, and the dns routes
# TODO: I should set up tagging of nodes via chef or terraform
# ------------------------------------------------------------------------------

job "cloudflared-tunnel" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "system"

  constraint {
    attribute = "${meta.tunnel}"
    operator  = "="
    value     = "1"
  }

  group "cloudflared" {
    # Host networking so 127.0.0.1 inside the container = host network namespace
    network { mode = "host" }

    task "cloudflared" {
      driver = "docker"

      config {
        image = "cloudflare/cloudflared:latest"
        # Host net mode inside Docker as well
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
  # NOTE: Pin these origins to the node that actually runs Traefik (mccoy).
  - hostname: "resume.alexfreidah.com"
    service: http://traefik.munchbox:80
  - hostname: "www.resume.alexfreidah.com"
    service: http://traefik.munchbox:80
  - service: http_status:404

warp-routing:
  enabled: true
EOF
  }
      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
