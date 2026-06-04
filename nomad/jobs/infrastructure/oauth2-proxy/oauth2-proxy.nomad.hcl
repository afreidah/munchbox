# -------------------------------------------------------------------------------
# OAuth2 Proxy — Google OAuth Forward Auth
#
# Project: Munchbox / Author: Alex Freidah
#
# Lightweight forward auth proxy using Google OAuth. Allows specific email
# addresses to access protected services via Traefik forward auth. Runs on
# all ingress nodes for HA — Traefik discovers instances via Consul DNS.
# -------------------------------------------------------------------------------

job "oauth2-proxy" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "system"
  node_pool   = "all"

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
    health_check     = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
    auto_revert      = true
    stagger          = "30s"
  }

  # ---------------------------------------------------------------------------
  # Placement — Run on ingress nodes only
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  # ---------------------------------------------------------------------------
  # Task Group: OAuth2 Proxy
  # ---------------------------------------------------------------------------

  group "oauth2-proxy" {

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
        static = 4180
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
      name     = "oauth2-proxy"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        # HTTPS router
        "traefik.http.routers.oauth2-proxy.rule=Host(`auth.munchbox.cc`)",
        "traefik.http.routers.oauth2-proxy.entrypoints=websecure",
        "traefik.http.routers.oauth2-proxy.tls=true",
        "traefik.http.routers.oauth2-proxy.tls.certresolver=letsencrypt",
        "traefik.http.routers.oauth2-proxy.middlewares=auth-ratelimit@file",
        # HTTP router (for Cloudflare tunnel)
        "traefik.http.routers.oauth2-proxy-http.rule=Host(`auth.munchbox.cc`) && HeaderRegexp(`CF-Connecting-IP`, `.+`)",
        "traefik.http.routers.oauth2-proxy-http.entrypoints=web",
        "traefik.http.routers.oauth2-proxy-http.middlewares=cf-tunnel-https@file,auth-ratelimit@file",
        "traefik.http.routers.oauth2-proxy-http.service=oauth2-proxy",
        # HTTP router (LAN - redirect to HTTPS)
        "traefik.http.routers.oauth2-proxy-lan.rule=Host(`auth.munchbox.cc`)",
        "traefik.http.routers.oauth2-proxy-lan.entrypoints=web",
        "traefik.http.routers.oauth2-proxy-lan.middlewares=redirect-https@file",
        "traefik.http.routers.oauth2-proxy-lan.priority=1",
        # Load balancer port
        "traefik.http.services.oauth2-proxy.loadbalancer.server.port=4180"
      ]

      check {
        name     = "oauth2-proxy-health"
        type     = "http"
        path     = "/ping"
        interval = "10s"
        timeout  = "3s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: OAuth2 Proxy
    # -------------------------------------------------------------------------

    task "oauth2-proxy" {
      driver = "docker"

      # --- Vault Integration ---
      vault {
        role = "nomad-workloads"
      }

      # --- Workload Identity ---
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Container Configuration ---
      config {
        image              = "quay.io/oauth2-proxy/oauth2-proxy:v7.15.2"
        image_pull_timeout = "5m"
        network_mode       = "host"
        ports              = ["http"]
        volumes = [
          "secrets/authenticated-emails.txt:/etc/oauth2-proxy/authenticated-emails.txt:ro"
        ]
      }

      # --- Environment Variables (static) ---
      env {
        OAUTH2_PROXY_HTTP_ADDRESS              = "0.0.0.0:4180"
        OAUTH2_PROXY_PROVIDER                  = "google"
        OAUTH2_PROXY_EMAIL_DOMAINS             = "*"
        OAUTH2_PROXY_COOKIE_DOMAINS            = ".munchbox.cc"
        OAUTH2_PROXY_WHITELIST_DOMAINS         = ".munchbox.cc"
        OAUTH2_PROXY_COOKIE_SECURE             = "true"
        OAUTH2_PROXY_COOKIE_SAMESITE           = "lax"
        OAUTH2_PROXY_REVERSE_PROXY             = "true"
        OAUTH2_PROXY_SET_XAUTHREQUEST          = "true"
        OAUTH2_PROXY_SET_AUTHORIZATION_HEADER  = "true"
        OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER = "true"
        OAUTH2_PROXY_PASS_ACCESS_TOKEN         = "true"
        OAUTH2_PROXY_PASS_USER_HEADERS         = "true"
        OAUTH2_PROXY_REDIRECT_URL              = "https://auth.munchbox.cc/oauth2/callback"
        OAUTH2_PROXY_UPSTREAMS                 = "static://202"
        OAUTH2_PROXY_AUTHENTICATED_EMAILS_FILE = "/etc/oauth2-proxy/authenticated-emails.txt"
      }

      # --- Secrets from Vault (as env file) ---
      template {
        data = <<EOF
{{ with secret "secret/data/oauth2-proxy" }}
OAUTH2_PROXY_CLIENT_ID={{ .Data.data.client_id }}
OAUTH2_PROXY_CLIENT_SECRET={{ .Data.data.client_secret }}
OAUTH2_PROXY_COOKIE_SECRET={{ .Data.data.cookie_secret }}
{{ end }}
EOF
        destination = "secrets/oauth2-proxy.env"
        env         = true
        change_mode = "restart"
      }

      # --- Authenticated Emails File ---
      template {
        data = <<EOF
{{ with secret "secret/data/oauth2-proxy" }}{{ .Data.data.allowed_emails }}{{ end }}
EOF
        destination = "secrets/authenticated-emails.txt"
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu    = 50
        memory = 32
      }

      # --- Termination ---
      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
