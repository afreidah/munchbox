# -------------------------------------------------------------------------------
# cloudflared-tunnel — Cloudflare Tunnel Connector
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs cloudflared connector using token-based auth on all ingress nodes.
# Cloudflare natively supports multiple connectors per tunnel for HA.
# Tunnel ingress configuration is managed by Terraform
# (infrastructure/terraform/dns/main.tf) via the cloudflare_tunnel_config
# resource. This job just runs the connector.
#
# To update tunnel routing: modify Terraform, not this file.
# -------------------------------------------------------------------------------

job "cloudflared-tunnel" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "system"
  node_pool   = "all"
  priority    = 50

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
    tier       = "tier-0"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = true
    stagger          = "30s"
  }

  # -------------------------------------------------------------------------
  # Placement — Run on ingress nodes only
  # -------------------------------------------------------------------------

  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  # ---------------------------------------------------------------------------
  # Task Group: cloudflared-tunnel
  # ---------------------------------------------------------------------------

  group "cloudflared-tunnel" {

    # --- Network Configuration ---
    network {
      mode = "host"
      port "metrics" {
        static = 2000
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Service Registration ---
    service {
      name     = "cloudflared-tunnel"
      port     = "metrics"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "infrastructure",
        "cloudflare",
        "tunnel",
        "ingress",
      ]
      check {
        name     = "cloudflared-tunnel-health"
        type     = "http"
        path     = "/ready"
        port     = "metrics"
        interval = "10s"
        timeout  = "3s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: cloudflared-tunnel
    # -------------------------------------------------------------------------

    task "cloudflared-tunnel" {
      driver = "docker"
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "cloudflare/cloudflared:2026.1.2"
        image_pull_timeout = "10m"
        ports              = ["metrics"]
        network_mode       = "host"
        args = [
          "tunnel",
          "--metrics", "0.0.0.0:2000",
          "run",
          "--token", "${TUNNEL_TOKEN}"
        ]
      }

      # --- Tunnel token from Vault ---
      # Token includes credentials and tunnel ID. Ingress config fetched from CF API.
      # Generate token: Cloudflare Dashboard > Zero Trust > Networks > Tunnels > Configure
      template {
        data        = <<EOH
{{ with secret "secret/data/cloudflared" }}
TUNNEL_TOKEN={{ .Data.data.tunnel_token }}
{{ end }}
EOH
        destination = "secrets/cloudflared.env"
        env         = true
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu    = 100
        memory = 128
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
