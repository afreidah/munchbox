# -------------------------------------------------------------------------------
#  Cloudflare Tunnel — Ingress Gateway with Dynamic YAML Configuration
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Runs cloudflared as a system job on the ingress node (mccoy) with host
#  networking. Renders tunnel credentials and YAML configuration via Nomad
#  templates from Consul KV, routing multiple hostnames to traefik.munchbox:80.
# -------------------------------------------------------------------------------

job "cloudflared-tunnel" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "system"
  node_pool   = "core"

  # ---------------------------------------------------------------------------
  #  Cloudflared Group
  # ---------------------------------------------------------------------------

  group "cloudflared" {

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    # --- Network configuration ---
    network {
      mode = "host"
    }

    # --- Task restart behavior ---
    restart {
      attempts = 5
      interval = "5m"
      delay    = "10s"
      mode     = "delay"
    }

    # -----------------------------------------------------------------------
    #  Cloudflared Task
    # -----------------------------------------------------------------------

    task "cloudflared" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image        = "cloudflare/cloudflared:latest"
        force_pull   = true
        network_mode = "host"
        args = [
          "tunnel",
          "--config", "/etc/cloudflared/config.yml",
          "run"
        ]
        volumes = [
          "local/config.yml:/etc/cloudflared/config.yml:ro",
          "local/credentials.json:/etc/cloudflared/credentials.json:ro"
        ]
      }

      # --- Cloudflared configuration templates ---
      template {
        destination   = "local/credentials.json"
        change_mode   = "restart"
        change_signal = "SIGTERM"
        data          = <<-EOF
{{ key "secrets/cloudflared/credentials.json" }}
EOF
      }

      template {
        destination   = "local/config.yml"
        change_mode   = "restart"
        change_signal = "SIGTERM"
        data          = <<-EOF
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

      # --- Resource allocation ---
      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
