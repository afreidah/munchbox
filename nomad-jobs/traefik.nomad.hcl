###############################################################################
# Traefik Reverse Proxy — Nomad Job (values pulled from Consul KV)
#
# - Exposes dashboard locally (8081)
# - Exposes internal HTTP (80)
# - Exposes HTTPS via VPN port (fetched from Consul KV)
# - Uses Cloudflare API token (fetched from Consul KV)
###############################################################################


# ──────────────────────────────────────────────────────────────
#  Render the job with values from Consul KV
# ──────────────────────────────────────────────────────────────

job "traefik" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"

  group "traefik" {
    count = 1

    # Only run on nodes labeled as "vpn"
    constraint {
      attribute = "${node.class}"
      operator  = "="
      value     = "vpn"
    }

    # Bind static ports directly via host networking
    network {
      port "http"      { static = 80 }
      port "https"     { static = 48060 }
      port "dashboard" { static = 8081 }
    }

    # Expose Traefik service to Consul for discovery
    service {
      name     = "traefik"
      port     = "https"
      provider = "consul"

      check {
        name     = "https-alive"
        type     = "tcp"
        port     = "https"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # Shared volume for config and ACME certs
    volume "shared_data" {
      type      = "host"
      source    = "shared_data"
      read_only = false
    }

    task "traefik" {
      driver = "docker"

      vault {
        policies = ["traefik-nomad"]
      }

      config {
        image        = "traefik:v2.11"
        network_mode = "host"

        volumes = [
          "shared-data:/etc/traefik",
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "/opt/nomad/data/traefik/acme.json:/etc/traefik/acme.json",
        ]
      }

      env {
        TRAEFIK_LOG_LEVEL        = "DEBUG"
        CLOUDFLARE_DNS_API_TOKEN = "${NOMAD_SECRETS_cf_api_token}"
      }

      logs {
        max_files     = 3
        max_file_size = 5
      }

      template {
        destination = "local/traefik.toml"
        perms       = "0644"
        change_mode = "noop"
        data = <<-TOML
          [entryPoints]
            [entryPoints.web]
              address = ":80"

            [entryPoints.websecure]
              address = ":48060"

            [entryPoints.dashboard]
              address = "192.168.1.225:8081"

          [api]
            dashboard = true
            insecure  = true

          [providers.consulCatalog]
            prefix           = "traefik"
            exposedByDefault = false

            [providers.consulCatalog.endpoint]
              address = "127.0.0.1:8500"
              scheme  = "http"

          [certificatesResolvers.dns.acme]
            email   = "alex.freidah@gmail.com"
            storage = "/etc/traefik/acme.json"

            [certificatesResolvers.dns.acme.dnsChallenge]
              provider = "cloudflare"
        TOML
      }

      resources {
        cpu    = 200
        memory = 256
      }

      restart {
        attempts = 3
        interval = "10m"
        delay    = "5s"
        mode     = "delay"
      }
    }
  }
}
