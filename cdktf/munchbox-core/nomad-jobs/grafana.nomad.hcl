# ------------------------------------------------------------------------------
# Grafana — Nomad Job (HTTPS on https://grafana.munchbox) — v12.2.0 + Vault WI
# ------------------------------------------------------------------------------

job "grafana" {
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
      port "web" { static = 3000 }
    }

    task "fix-perms" {
      driver = "docker"
      lifecycle { hook = "prestart" }
      config {
        image   = "alpine:3.20"
        command = "sh"
        args    = ["-c", "mkdir -p /var/lib/grafana && chown -R 472:472 /var/lib/grafana && ls -ld /var/lib/grafana"]
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

      # Vault Workload Identity: use JWT role that issues token with the right policies
      vault { role = "nomad-grafana" }

      # Workload Identity JWT (so we can verify iss/aud easily)
      identity {
        env  = true
        file = true         # <-- bool, writes to secrets/identity/jwt
        aud  = ["vault.io"] # must match role.bound_audiences
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
          "monitoring", "grafana",
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
        volumes            = ["local/grafana-provisioning:/etc/grafana/provisioning"]
      }

      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
        read_only   = false
      }

      # Debug: show the policies on the Vault token Nomad got via WI login
      template {
        destination = "secrets/_debug_policies.txt"
        perms       = "0600"
        data        = "{{ with secret \"auth/token/lookup-self\" }}{{ .Data.policies }}{{ end }}"
      }

      # Render admin creds from KV v2
      template {
        destination = "secrets/grafana.env"
        env         = true
        data        = <<EOH
{{ with secret "secret/data/grafana" }}
GF_SECURITY_ADMIN_USER={{ .Data.data.admin_user }}
GF_SECURITY_ADMIN_PASSWORD={{ .Data.data.admin_password }}
{{ end }}
EOH
      }

      env = {
        GF_SERVER_SERVE_FROM_SUB_PATH = "false"
        GF_SERVER_ROOT_URL            = "https://grafana.munchbox/"
      }

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
