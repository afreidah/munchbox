# -------------------------------------------------------------------------------
# cloudflared-tunnel — Munchbox Deployment
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job "cloudflared-tunnel" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "system"
  node_pool   = "all"
  priority    = 50

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
  # Placement
  # -------------------------------------------------------------------------

  # --- Pin to ingress nodes ---
  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "stabler.munchbox.cc"
  }

  # ---------------------------------------------------------------------------
  # Task Group: cloudflared-tunnel
  # ---------------------------------------------------------------------------

  group "cloudflared-tunnel" {

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
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
      port     = "http"
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
        port     = "http"
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
        image              = "cloudflare/cloudflared:latest"
        image_pull_timeout = "10m"
        ports              = ["http"]
        network_mode       = "host"
        args               = ["tunnel", "--config", "/secrets/config.yml", "run"]
        volumes            = ["secrets/credentials.json:/local/credentials.json:ro", "secrets/config.yml:/local/config.yml:ro"]
      }
      template {
        data        = <<EOH
{{ with secret "secret/data/cloudflared" }}{{ .Data.data.credentials_json }}{{ end }}

EOH
        destination = "secrets/credentials.json"
        change_mode = "restart"
      }
      template {
        data        = <<EOH
tunnel: {{ with secret "secret/data/cloudflared" }}{{ .Data.data.tunnel_uuid }}{{ end }}
credentials-file: /local/credentials.json

# Enable metrics and health endpoints
metrics: 0.0.0.0:2000

ingress:
  # --- alexfreidah.com domains ---
  - hostname: "alexfreidah.com"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: alexfreidah.com

  - hostname: "www.alexfreidah.com"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: www.alexfreidah.com

  - hostname: "resume.alexfreidah.com"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: resume.alexfreidah.com

  - hostname: "k3s-status.alexfreidah.com"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: k3s-status.alexfreidah.com

  # --- munchbox.cc domains (Authentik-protected) ---
  - hostname: "dashboard.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: dashboard.munchbox.cc

  - hostname: "nomad.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: nomad.munchbox.cc

  - hostname: "consul.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: consul.munchbox.cc

  - hostname: "traefik.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: traefik.munchbox.cc

  - hostname: "auth.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: auth.munchbox.cc

  - hostname: "nextcloud.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: nextcloud.munchbox.cc

  - hostname: "prometheus.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: prometheus.munchbox.cc

  - hostname: "grafana.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: grafana.munchbox.cc

  - hostname: "vaultwarden.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: vaultwarden.munchbox.cc

  - hostname: "alertmanager.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: alertmanager.munchbox.cc

  - hostname: "emby.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: emby.munchbox.cc

  - hostname: "jellyfin.munchbox.cc"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: jellyfin.munchbox.cc

  - service: http_status:404

warp-routing:
  enabled: false

EOH
        destination = "secrets/config.yml"
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
  meta = {
    managed_by             = "nomad-pack"
    "pack.deployment_name" = "munchbox-service"
    "pack.job"             = "cloudflared-tunnel"
    "pack.name"            = "munchbox-service"
    "pack.path"            = "/home/afreidah/tools/munchbox/nomad/packs/registry/munchbox-service"
    "pack.registry"        = "<<local folder>>"
    "pack.version"         = "<<none>>"
    project                = "munchbox"
  }
}

