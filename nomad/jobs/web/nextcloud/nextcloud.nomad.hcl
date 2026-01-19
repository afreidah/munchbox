# -------------------------------------------------------------------------------
# Nextcloud — Self-hosted Cloud Storage and Collaboration Platform
#
# Project: Munchbox / Author: Alex Freidah
#
# Nextcloud with Redis for caching/locking and cron for background jobs.
# Uses Postgres for database and stores user data on /mnt/gdrive.
# -------------------------------------------------------------------------------

job "nextcloud" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 50

  # -------------------------------------------------------------------------
  # Update Strategy
  # -------------------------------------------------------------------------

  update {
    max_parallel      = 1
    canary            = 1
    health_check      = "task_states"
    min_healthy_time  = "30s"
    healthy_deadline  = "10m"
    progress_deadline = "15m"
    auto_revert       = true
    auto_promote      = true
  }

  # -------------------------------------------------------------------------
  # Task Group: nextcloud
  # -------------------------------------------------------------------------

  group "nextcloud" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }

    # -----------------------------------------------------------------------
    # Network Configuration
    # -----------------------------------------------------------------------
      
    network {
      mode = "bridge"
      port "http" {
        to     = 80
        static = 18081
      }
      # Bridge mode containers need explicit DNS config at network level
      # Use goren's local dnsmasq for Consul DNS resolution
      dns {
        servers  = ["192.168.68.60", "192.168.68.64", "192.168.68.62"]
        searches = ["service.consul"]
        options  = ["ndots:1", "timeout:2", "attempts:2"]
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # -----------------------------------------------------------------------
    # Service Registration
    # -----------------------------------------------------------------------

    service {
      name     = "nextcloud"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        # HTTPS router for API/OCS (no oauth2-proxy - Nextcloud handles auth)
        "traefik.http.routers.nextcloud-api.rule=Host(`nextcloud.munchbox.cc`) && (PathPrefix(`/ocs`) || PathPrefix(`/remote.php`) || PathPrefix(`/public.php`) || PathPrefix(`/status.php`))",
        "traefik.http.routers.nextcloud-api.entrypoints=websecure",
        "traefik.http.routers.nextcloud-api.tls=true",
        "traefik.http.routers.nextcloud-api.tls.certresolver=letsencrypt",
        "traefik.http.routers.nextcloud-api.middlewares=nextcloud-ratelimit@file,nextcloud-sec@file",
        "traefik.http.routers.nextcloud-api.priority=20",
        # HTTP router for API/OCS (Cloudflare tunnel, no oauth2-proxy)
        "traefik.http.routers.nextcloud-api-http.rule=Host(`nextcloud.munchbox.cc`) && (PathPrefix(`/ocs`) || PathPrefix(`/remote.php`) || PathPrefix(`/public.php`) || PathPrefix(`/status.php`))",
        "traefik.http.routers.nextcloud-api-http.entrypoints=web",
        "traefik.http.routers.nextcloud-api-http.middlewares=cf-tunnel-https@file,nextcloud-ratelimit@file,nextcloud-sec@file",
        "traefik.http.routers.nextcloud-api-http.priority=20",
        # HTTPS router for Web UI (with oauth2-proxy)
        "traefik.http.routers.nextcloud.rule=Host(`nextcloud.munchbox.cc`)",
        "traefik.http.routers.nextcloud.entrypoints=websecure",
        "traefik.http.routers.nextcloud.tls=true",
        "traefik.http.routers.nextcloud.tls.certresolver=letsencrypt",
        "traefik.http.routers.nextcloud.middlewares=oauth2-proxy@file,nextcloud-ratelimit@file,nextcloud-sec@file,umami-tracking@file",
        "traefik.http.routers.nextcloud.priority=10",
        # HTTP router for Web UI (Cloudflare tunnel, with oauth2-proxy)
        "traefik.http.routers.nextcloud-http.rule=Host(`nextcloud.munchbox.cc`)",
        "traefik.http.routers.nextcloud-http.entrypoints=web",
        "traefik.http.routers.nextcloud-http.middlewares=cf-tunnel-https@file,oauth2-proxy@file,nextcloud-ratelimit@file,nextcloud-sec@file,umami-tracking@file",
        "traefik.http.routers.nextcloud-http.priority=10",
        "traefik.http.services.nextcloud.loadbalancer.server.port=18081",
        "cloud",
        "files",
        "collaboration",
        "web"
      ]

      check {
        name     = "nextcloud-health"
        type     = "http"
        path     = "/status.php"
        port     = "http"
        interval = "30s"
        timeout  = "10s"
      }
    }

    # -----------------------------------------------------------------------
    # Task: nextcloud
    # -----------------------------------------------------------------------

    task "nextcloud" {
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
        image              = "nextcloud:32.0-apache"
        image_pull_timeout = "10m"
        volumes            = [
          "/mnt/gdrive/nextcloud/data:/var/www/html/data",
          "/opt/nomad/data/nextcloud/config:/var/www/html/config",
          "/opt/nomad/data/nextcloud/apps:/var/www/html/custom_apps"
        ]
      }

      # --- Environment Variables (static) ---
      env {
        POSTGRES_HOST        = "postgres-primary.service.consul"
        POSTGRES_DB          = "nextcloud"
        REDIS_HOST           = "redis-primary.service.consul"
        REDIS_PORT           = "6379"
        REDIS_HOST_PORT      = "6379"
        REDIS_HOST_DB        = "0"
        TRUSTED_PROXIES      = "172.26.64.0/18"
        OVERWRITEPROTOCOL    = "https"
        OVERWRITEHOST        = "nextcloud.munchbox.cc"
        OVERWRITECLIURL      = "https://nextcloud.munchbox.cc"
      }

      # --- Dynamic Secrets from Vault ---
      template {
        destination = "secrets/env.sh"
        env         = true
        change_mode = "restart"
        data        = <<-EOF
{{ with secret "secret/data/nextcloud" }}
POSTGRES_PASSWORD={{ .Data.data.db_password }}
{{ end }}
{{ with secret "secret/data/redis-shared" }}
REDIS_HOST_PASSWORD={{ .Data.data.password }}
{{ end }}
        EOF
      }

      # --- Resources ---
      resources {
        cpu    = 3500
        memory = 2048
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }

    # -----------------------------------------------------------------------
    # Sidecar Task: cron
    # -----------------------------------------------------------------------

    task "cron" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image      = "nextcloud:apache"
        entrypoint = ["/cron.sh"]
        volumes    = [
          "/mnt/gdrive/nextcloud/data:/var/www/html/data",
          "/opt/nomad/data/nextcloud/config:/var/www/html/config",
          "/opt/nomad/data/nextcloud/apps:/var/www/html/custom_apps"
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  meta = {
    managed_by = "nomad"
    project    = "munchbox"
  }
}
