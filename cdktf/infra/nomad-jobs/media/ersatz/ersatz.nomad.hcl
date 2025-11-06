# -------------------------------------------------------------------------------
#  ErsatzTV — Virtual TV Channel Engine with Emby Integration
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Creates virtual TV channels from Emby library (TV + Movies). Generates
#  scheduled broadcasts with guide data and streaming interface. Runs on mccoy
#  node with access to media libraries. Exposes web UI/API on :8409 for channel
#  management and stream playback configuration.
# -------------------------------------------------------------------------------

job "ersatztv" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # --- Job metadata ---
  meta {
    version     = "0.8.0"
    owner       = "alex.freidah"
    category    = "media"
    tier        = "tier-2"
    environment = "production"
    description = "ErsatzTV virtual TV channel engine with Emby backend"
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
  #  ErsatzTV Group
  # ---------------------------------------------------------------------------

  group "ersatztv" {
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
      port "ui" {
        static = 8409
        to     = 8409
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
    #  ErsatzTV Virtual Channel Task
    # -----------------------------------------------------------------------

    task "ersatztv" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image              = "jasongdove/ersatztv:latest"
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["ui"]
        readonly_rootfs    = false
        volumes = [
          "/opt/nomad/data/ersatztv/config:/config",
          "/opt/nomad/data/ersatztv/transcode:/transcode",
          "/mnt/gdrive/media/Movies:/media/Movies:ro",
          "/mnt/gdrive/media/TV:/media/TV:ro"
        ]
      }

      # --- Runtime environment ---
      env {
        TZ = "UTC"
      }

      # --- Service registration ---
      service {
        name = "ersatztv"
        port = "ui"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.ersatztv.rule=Host(`ersatz.munchbox`)",
          "traefik.http.routers.ersatztv.entrypoints=websecure",
          "traefik.http.routers.ersatztv.tls=true",
          "traefik.http.routers.ersatztv.middlewares=dashboard-allowlan@file",
          "traefik.http.services.ersatztv.loadbalancer.server.port=8409",
          "media",
          "ersatztv",
          "streaming"
        ]

        # --- Web UI health check ---
        check {
          name     = "ersatztv-ui"
          type     = "http"
          path     = "/"
          interval = "15s"
          timeout  = "3s"
        }
      }

      # --- Resource allocation ---
      resources {
        cpu    = 500
        memory = 1024
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
