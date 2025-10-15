# -------------------------------------------------------------------------------
# ErsatzTV — Nomad service job (TV + Movies only)
# -------------------------------------------------------------------------------

job "ersatztv" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "ersatztv" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    network {
      mode = "host"

      # ErsatzTV UI/API
      port "ui" { 
        static = 8409 
        to     = 8409
      }
    }

    task "ersatztv" {
      driver = "docker"

      resources {
        cpu    = 500
        memory = 1024
      }

      restart {
        attempts = 3
        interval = "5m"
        delay    = "15s"
        mode     = "delay"
      }

      logs {
        max_files     = 5
        max_file_size = 20
      }

      config {
        image              = "jasongdove/ersatztv:latest"
        image_pull_timeout = "10m"
        ports              = ["ui"]
        network_mode       = "host"
        readonly_rootfs    = false

        # Direct host binds (no Nomad volume blocks)
        volumes = [
          # Config/database (writable)
          "/opt/nomad/data/ersatztv/config:/config",

          # Optional: transcode scratch (host-backed; replace with tmpfs if desired)
          "/opt/nomad/data/ersatztv/transcode:/transcode",

          # Media (read-only) — TV + Movies only, matching Emby’s container paths
          "/mnt/gdrive/media/Movies:/media/Movies:ro",
          "/mnt/gdrive/media/TV:/media/TV:ro"

          # Alternative: bind the entire tree once (not needed here)
          # "/mnt/gdrive/media:/media:ro"
        ]

        # HW transcoding (optional):
        # - Swap image to :latest-vaapi and expose /dev/dri, or use :latest-nvidia on NVIDIA hosts.
        # devices = [
        #   { host_path = "/dev/dri", container_path = "/dev/dri", cgroup_permissions = "rwm" }
        # ]

        logging {
          type = "journald"
          config { tag = "ersatztv" }
        }
      }

      env = {
        TZ = "UTC"
        # Configure Emby in the UI after first run (Server URL + API key).
      }

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
          "streaming",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "15s"
          timeout  = "3s"
        }
      }

      kill_timeout = "30s"
    }
  }
}
