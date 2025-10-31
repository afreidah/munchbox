# ------------------------------------------------------------------------------
# Grafana — Nomad Job (HTTPS via Traefik @ https://grafana.munchbox) — v12.2.0
# Vault Workload Identity (JWT) enabled. Host networking. Consul-backed DNS.
# ------------------------------------------------------------------------------
# Rationale:
# - Dynamic connectivity: Grafana targets Prometheus via Consul DNS, not node IPs.
# - Docker DNS is pinned to Pi-hole/Unbound resolvers that forward .consul to Consul.
# - Host networking simplifies exposure; Traefik routes HTTPS externally.
# - Provisioned datasources are authoritative to prevent drift from UI edits.
# ------------------------------------------------------------------------------

job "grafana" {
  meta {
    version     = "1.0.1"
    owner       = "alex.freidah"
    category    = "monitoring"
    tier        = "tier-1"
    environment = "production"
    description = "grafana service with Promtail/Loki observability additions"
  }

  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "edge"

  group "grafana" {
    count = 1

    constraint {
      attribute = "${node.class}"
      operator  = "="
      value     = "utility"
    }

    volume "grafana-data" {
      type      = "host"
      source    = "grafana-data"
      read_only = false
    }

    network {
      mode = "host"
      port "web" {
        static = 3000
        to     = 3000
      }
    }

    task "fix-perms" {
      driver = "docker"
      lifecycle { hook = "prestart" }

      config {
        image   = "alpine:3.20"
        command = "sh"
        args = [
          "-c",
          "mkdir -p /var/lib/grafana && chown -R 472:472 /var/lib/grafana && ls -ld /var/lib/grafana"
        ]
      }

      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
        read_only   = false
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    task "grafana" {
      driver = "docker"

      vault { role = "nomad-grafana" }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      service {
        name     = "grafana"
        port     = "web"
        provider = "consul"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=Host(`grafana.munchbox`)",
          "traefik.http.routers.grafana.entrypoints=websecure",
          "traefik.http.routers.grafana.tls=true",
          "traefik.http.routers.grafana.middlewares=dashboard-allowlan@file",
          "traefik.http.services.grafana.loadbalancer.server.port=3000",
          "monitoring",
          "grafana",
        ]

        check {
          name     = "grafana-alive"
          type     = "http"
          path     = "/api/health"
          port     = "web"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image              = "grafana/grafana:12.2.0"
        ports              = ["web"]
        image_pull_timeout = "10m"
        network_mode       = "host"

        dns_servers        = ["192.168.68.62", "192.168.68.64"]
        dns_search_domains = ["service.consul"]
        dns_options        = ["timeout:2", "attempts:3", "ndots:1"]

        volumes = [
          "local/grafana-provisioning:/etc/grafana/provisioning"
        ]
      }

      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
        read_only   = false
      }

      template {
        destination = "secrets/_debug_policies.txt"
        perms       = "0600"
        data        = "{{ with secret \"auth/token/lookup-self\" }}{{ .Data.policies }}{{ end }}"
      }

      template {
        destination = "secrets/grafana.env"
        env         = true
        data        = <<EOH
<<INJECT:files/grafana.env>>
EOH
      }

      env = {
        GF_SERVER_SERVE_FROM_SUB_PATH = "false"
        GF_SERVER_ROOT_URL            = "https://grafana.munchbox/"
        NO_PROXY                      = "localhost,127.0.0.1,*.service.consul,service.consul,192.168.68.0/24"
      }

      # ----------------------------------------------------------------------
      # Provisioned datasources (authoritative)
      # - Prometheus via Consul DNS (dynamic, node-agnostic)
      # - Loki via Consul DNS
      # - Includes Promtail/Loki metrics jobs for observability
      # ----------------------------------------------------------------------

      template {
        destination = "local/grafana-provisioning/datasources/ds.yml"
        perms       = "0644"
        data        = <<YAML
<<INJECT:files/ds.yml>>
YAML
      }

      resources {
        cpu    = 250
        memory = 512
      }

      restart {
        attempts = 5
        interval = "10m"
        delay    = "30s"
        mode     = "fail"
      }
    }
  }
}
