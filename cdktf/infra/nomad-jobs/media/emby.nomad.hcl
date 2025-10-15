# -------------------------------------------------------------------------------
# Emby Media Server — Nomad service job (Option B: direct binds, no Nomad volumes)
#
# * Runs Emby via linuxserver/emby.
# * Persists config/cache using direct host binds (no Nomad volume blocks).
# * Binds media from /mnt/gdrive/media (read-only per directory).
# * Exposes web UI on port 8096 (optional HTTPS on 8920).
# * Registers service with Consul and tags for Traefik HTTP routing.
# * Constrained to node "mccoy" where the media path exists locally.
#
# Sizing:
# - resources.cpu=2000 (~2 cores), memory=4096, memory_max=6144 — good starting point.
# - Increase if software-transcoding 1080p/4K or if scans/transcodes spike usage.
#
# Notes:
# - No Nomad tmpfs support used here; /transcode is disk-backed. If you want
#   tmpfs, create a host tmpfs/ramdisk and bind-mount it in volumes instead.
# -------------------------------------------------------------------------------

job "emby" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "emby" {
    count = 1

    # Ensure this job runs where the media is locally mounted
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    network {
      mode = "host"
      port "web" { static = 8096 }   # Emby HTTP
      port "https" { static = 8920 } # Emby HTTPS (optional)
    }

    task "emby" {
      driver = "docker"

      # -----------------------------
      # Resource profile (moderate)
      # -----------------------------
      resources {
        cpu    = 2000 # ~2 CPU shares
        memory = 4096 # soft memory (MB)
      }

      # Robust restart behavior for spikes/updates
      restart {
        attempts = 3
        interval = "5m"
        delay    = "15s"
        mode     = "delay"
      }

      # Keep container logs under control
      logs {
        max_files     = 5
        max_file_size = 20
      }

      config {
        image              = "linuxserver/emby:latest"
        image_pull_timeout = "10m"
        ports              = ["web", "https"]
        network_mode       = "host"
        readonly_rootfs    = false

        # Direct host binds (no Nomad volume blocks)
        volumes = [
          # Config & cache (writable)
          "/opt/nomad/data/emby/config:/config",
          "/opt/nomad/data/emby/cache:/cache",

          # Disk-backed transcode scratch (set Emby Transcoding path to /transcode)
          "/opt/nomad/data/emby/transcode:/transcode",

          # Media (read-only) — bind each top-level directory explicitly
          "/mnt/gdrive/media/Movies:/media/Movies:ro",
          "/mnt/gdrive/media/TV:/media/TV:ro",
          "/mnt/gdrive/media/Music:/media/Music:ro",
          "/mnt/gdrive/media/Books:/media/Books:ro",
          "/mnt/gdrive/media/ISOs:/media/ISOs:ro",
          "/mnt/gdrive/media/Software:/media/Software:ro",
          "/mnt/gdrive/media/hacker-magazines:/media/hacker-magazines:ro",
          "/mnt/gdrive/media/random:/media/random:ro",
          "/mnt/gdrive/media/taxes:/media/taxes:ro"

          # Alternative: bind the entire tree once (adjust libraries in Emby)
          # "/mnt/gdrive/media:/media:ro"
        ]

        # Hardware transcoding (Intel/AMD iGPU) — object form required by Nomad
        devices = [
          {
            host_path          = "/dev/dri"
            container_path     = "/dev/dri"
            cgroup_permissions = "rwm"
          }
        ]

        # Optional: route via VPN policy like Deluge (requires host policy rules)
        # user = "vpnmark"
        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "emby"
          }
        }
      }

      env = {
        PUID = "1001" # Match ownership of your media/config paths
        PGID = "1001"
        TZ   = "UTC"
      }

      service {
        name = "emby"
        port = "web"

        tags = [
          "traefik.enable=true",

          # Router configuration
          "traefik.http.routers.emby.rule=Host(`emby.munchbox`)",
          "traefik.http.routers.emby.entrypoints=websecure",
          "traefik.http.routers.emby.tls=true",

          # Restrict to LAN (middleware defined in Traefik file provider)
          "traefik.http.routers.emby.middlewares=dashboard-allowlan@file",

          # Explicit backend port
          "traefik.http.services.emby.loadbalancer.server.port=8096",

          # Metadata tags
          "media",
          "emby",
          "streaming",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # Graceful stop to allow Emby to flush state
      kill_timeout = "30s"
    }
  }
}
