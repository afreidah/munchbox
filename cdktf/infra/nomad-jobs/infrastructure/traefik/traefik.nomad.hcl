# -------------------------------------------------------------------------------
#  Traefik — Reverse Proxy and Load Balancer with Dynamic Service Discovery
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  HTTPS-first ingress controller running as system job on designated ingress
#  nodes. Accepts HTTP for Cloudflare Tunnel and redirects *.munchbox to HTTPS.
#  Auto-discovers services via Consul Catalog and dynamic config. Generates
#  self-signed certificates for internal *.munchbox domains on first start.
#  Exposes dashboard on :8081 (LAN-only) for traffic analysis.
# -------------------------------------------------------------------------------

job "traefik" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "system"
  node_pool   = "core"

  # --- Job metadata ---
  meta {
    version     = "3.5.3"
    owner       = "alex.freidah"
    category    = "infrastructure"
    tier        = "tier-0"
    environment = "production"
    description = "Traefik reverse proxy with Consul service discovery"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
  }

  # --- Job-level placement constraints ---
  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  # ---------------------------------------------------------------------------
  #  Traefik Group
  # ---------------------------------------------------------------------------

  group "traefik" {
    # --- Network configuration ---
    network {
      mode = "host"
      port "dashboard" {
        static = 8081
        to     = 8081
      }
      port "http" {
        static = 80
        to     = 80
      }
      port "https" {
        static = 443
        to     = 443
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # -----------------------------------------------------------------------
    #  Certificate Generation Prestart Task
    # -----------------------------------------------------------------------

    task "certgen" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      # --- Docker image configuration ---
      config {
        image   = "alpine:latest"
        command = "sh"
        args    = ["-c", "apk add --no-cache openssl && /local/generate-certs.sh"]
      }

      # --- Certificate generation script template ---
      template {
        destination = "local/generate-certs.sh"
        perms       = "0755"
        data        = <<-EOT
<<INJECT:files/generate-certs.sh>>
EOT
      }

      # --- Resource allocation ---
      resources {
        cpu    = 300
        memory = 128
      }
    }

    # -----------------------------------------------------------------------
    #  Traefik Reverse Proxy Task
    # -----------------------------------------------------------------------

    task "traefik" {
      driver = "docker"

      # --- Workload identity and Vault integration ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker image configuration ---
      config {
        image        = "traefik:v3.5.3"
        network_mode = "host"
        ports        = ["http", "https", "dashboard"]
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/traefik_dynamic.toml:/etc/traefik/traefik_dynamic.toml"
        ]
      }

      # --- Consul configuration template ---
      template {
        destination = "secrets/consul.env"
        env         = true
        data        = <<-EOT
<<INJECT:files/consul.env.ctmpl>>
EOT
      }

      # --- Traefik static configuration template ---
      template {
        destination = "local/traefik.toml"
        perms       = "0644"
        data        = <<-EOT
<<INJECT:files/traefik.toml.ctmpl>>
EOT
      }

      # --- Traefik dynamic configuration template ---
      template {
        destination = "local/traefik_dynamic.toml"
        change_mode = "restart"
        perms       = "0644"
        data        = <<-EOT
<<INJECT:files/traefik_dynamic.toml.ctmpl>>
EOT
      }

      # --- Service registration (HTTPS endpoint) ---
      service {
        name = "traefik"
        port = "https"
        tags = ["metrics_port=8081"]

        # --- HTTPS health check ---
        check {
          name     = "traefik-https"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # --- Service registration (dashboard endpoint) ---
      service {
        name = "traefik-dashboard"
        port = "dashboard"

        # --- Dashboard health check ---
        check {
          name     = "traefik-ping"
          type     = "http"
          path     = "/ping"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # --- Resource allocation ---
      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
