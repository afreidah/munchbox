# ------------------------------------------------------------------------------
# Grafana — Nomad Job (HTTPS on https://grafana.munchbox) — v12.2.0 + fixed perms
#
# - Host networking (:3000)
# - Persistent data: host volume mounted directly at /var/lib/grafana
# - Prestart "fix-perms" chowns data dir to UID:GID 472:472 (Grafana's default)
# - Traefik via Consul tags: Host(`grafana.munchbox`) on websecure (TLS)
# ------------------------------------------------------------------------------

job "grafana" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "edge"

  group "grafana" {
    count = 1

    # --- Placement -------------------------------------------------------------
    constraint {
      attribute = "${node.class}"
      operator  = "="
      value     = "utility"
    }

    # --- Persistence: host volume ---------------------------------------------
    volume "grafana-data" {
      type      = "host"
      source    = "grafana-data"   # define in client.hcl
      read_only = false
    }

    # --- Networking: host mode, :3000 -----------------------------------------
    network {
      mode = "host"
      port "web" { static = 3000 }
    }

    # --- Prestart: ensure /var/lib/grafana is writable by UID 472 --------------
    task "fix-perms" {
      driver = "docker"
      lifecycle { hook = "prestart" }

      config {
        image   = "alpine:3.20"
        command = "sh"
        args    = ["-c", "mkdir -p /var/lib/grafana && chown -R 472:472 /var/lib/grafana && ls -ld /var/lib/grafana"]
      }

      # mount the same data volume into this task at the final path
      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
        read_only   = false
      }

      resources { 
        cpu = 50
        memory = 64
      }
    }

    # --- Grafana ---------------------------------------------------------------
    task "grafana" {
      driver = "docker"

      # Service registration (Consul + Traefik tags)
      service {
        name     = "grafana"
        port     = "web"
        provider = "consul"
        tags = [
          "traefik.enable=true",

          # Router: https://grafana.munchbox (TLS on :443)
          "traefik.http.routers.grafana.rule=Host(`grafana.munchbox`)",
          "traefik.http.routers.grafana.entrypoints=websecure",
          "traefik.http.routers.grafana.tls=true",

          # Restrict to LAN (middleware defined in Traefik file provider)
          "traefik.http.routers.grafana.middlewares=dashboard-allowlan@file",

          # Explicit backend port
          "traefik.http.services.grafana.loadbalancer.server.port=3000",

          # Metadata tags
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

      # Container config
      config {
        image              = "grafana/grafana:12.2.0"
        ports              = ["web"]
        image_pull_timeout = "10m"

        # Provisioning files (optional)
        volumes = [
          "local/grafana-provisioning:/etc/grafana/provisioning"
        ]
      }

      # Mount the host volume directly into the container at /var/lib/grafana
      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
        read_only   = false
      }

      # Admin creds (demo) — replace later
      template {
        destination = "secrets/grafana.env"
        env         = true
        data        = <<EOH
GF_SECURITY_ADMIN_PASSWORD=admin
EOH
      }

      # Grafana behind HTTPS host (no sub-path)
      env = {
        GF_SERVER_SERVE_FROM_SUB_PATH = "false"
        GF_SERVER_ROOT_URL            = "https://grafana.munchbox/"
      }

      # Optional: seed a Prometheus datasource at 127.0.0.1:9090
      template {
        destination = "local/grafana-provisioning/datasources/ds.yml"
        perms       = "0644"
        data        = <<YAML
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://127.0.0.1:9090
    isDefault: true
YAML
      }

      resources {
        cpu = 250
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
