# -------------------------------------------------------------------------------
#  Emby Media Server — Streaming Platform with Hardware Transcoding Support
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Media streaming server running on mccoy node with direct host volume binds
#  for config, cache, and media libraries. Supports hardware transcoding via
#  Intel/AMD iGPU. Exposes web UI on :8096 (HTTP) and :8920 (HTTPS). Media
#  sourced from mounted /mnt/gdrive with read-only access per library type.
# -------------------------------------------------------------------------------

job "emby" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # --- Job metadata ---
  meta {
    version     = "4.8.0"
    owner       = "alex.freidah"
    category    = "media"
    tier        = "tier-1"
    environment = "production"
    description = "Emby media server with GPU transcoding and library management"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  #  Emby Group
  # ---------------------------------------------------------------------------

  group "emby" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    # --- Network configuration ---
    network {
      mode = "host"
      port "web" {
        static = 8096
      }
      port "https" {
        static = 8920
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    # --- Reschedule policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # -----------------------------------------------------------------------
    #  Emby Media Server Task
    # -----------------------------------------------------------------------

    task "emby" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image              = "linuxserver/emby:latest"
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["web", "https"]
        readonly_rootfs    = false
        volumes = [
          "/opt/nomad/data/emby/config:/config",
          "/opt/nomad/data/emby/cache:/cache",
          "/opt/nomad/data/emby/transcode:/transcode",
          "/mnt/gdrive/media/Movies:/media/Movies:ro",
          "/mnt/gdrive/media/TV:/media/TV:ro",
          "/mnt/gdrive/media/Music:/media/Music:ro",
          "/mnt/gdrive/media/Books:/media/Books:ro",
          "/mnt/gdrive/media/ISOs:/media/ISOs:ro",
          "/mnt/gdrive/media/Software:/media/Software:ro",
          "/mnt/gdrive/media/hacker-magazines:/media/hacker-magazines:ro",
          "/mnt/gdrive/media/random:/media/random:ro",
          "/mnt/gdrive/media/taxes:/media/taxes:ro"
        ]
        devices = [
          {
            host_path          = "/dev/dri"
            container_path     = "/dev/dri"
            cgroup_permissions = "rwm"
          }
        ]
      }

      # --- Runtime environment ---
      env {
        PUID = "1001"
        PGID = "1001"
        TZ   = "UTC"
      }

      # --- Service registration ---
      service {
        name = "emby"
        port = "web"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.emby.rule=Host(`emby.munchbox`)",
          "traefik.http.routers.emby.entrypoints=websecure",
          "traefik.http.routers.emby.tls=true",
          "traefik.http.routers.emby.middlewares=dashboard-allowlan@file",
          "traefik.http.services.emby.loadbalancer.server.port=8096",
          "media",
          "emby",
          "streaming"
        ]

        # --- Web UI health check ---
        check {
          name     = "emby-web"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # --- Resource allocation ---
      resources {
        cpu        = 2000
        memory     = 4096
        memory_max = 6144
      }

      # --- Log rotation configuration ---
      logs {
        max_files     = 5
        max_file_size = 20
      }

      # --- Termination configuration ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
