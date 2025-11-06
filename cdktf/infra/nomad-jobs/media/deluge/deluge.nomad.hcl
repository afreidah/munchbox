# -------------------------------------------------------------------------------
#  Deluge — BitTorrent Client with VPN Integration and Web UI
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  BitTorrent client running on mccoy node with all traffic routed through
#  WireGuard VPN via policy-based marking. Persists configuration and downloads
#  on host volumes. Exposes web UI on :8112 for torrent management. Pulls
#  credentials from Vault for daemon auth and web password.
# -------------------------------------------------------------------------------

job "deluge" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # --- Job metadata ---
  meta {
    version     = "2.1.1"
    owner       = "alex.freidah"
    category    = "utility"
    tier        = "tier-2"
    environment = "production"
    description = "Deluge BitTorrent client with VPN policy routing"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  #  Deluge Group
  # ---------------------------------------------------------------------------

  group "deluge" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    # --- Deluge configuration storage volume ---
    volume "deluge-data" {
      type      = "host"
      source    = "deluge-data"
      read_only = false
    }

    # --- Network configuration ---
    network {
      mode = "host"
      port "web" {
        static = 8112
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
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
    #  Deluge BitTorrent Client Task
    # -----------------------------------------------------------------------

    task "deluge" {
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
        image              = "goren:5000/deluge-with-vpnmark:latest"
        image_pull_timeout = "10m"
        ports              = ["web"]
        readonly_rootfs    = false
        cap_add            = ["CHOWN", "FOWNER"]
        volumes = [
          "/opt/nomad/data/deluge-data/downloads:/downloads",
          "/mnt/gdrive/nomad_deluge_downloads:/completed"
        ]
        entrypoint = ["/bin/sh", "-c"]
        args = [
          <<-EOS
          set -euo pipefail

          # Provide defaults without brace-style parameter expansion to avoid parser traps
          if [ -z "$PUID" ]; then PUID=1001; fi
          if [ -z "$PGID" ]; then PGID=1001; fi

          # Ensure /config exists (should via volume), then force-write daemon auth.
          if [ -f /local/auth ]; then
            install -m 600 -o "$PUID" -g "$PGID" /local/auth /config/auth
          else
            echo "ERROR: /local/auth not rendered; check Vault secret kv/data/deluge" >&2
            exit 1
          fi

          # One-time Web UI reset (stale hostlist/web.conf causes auth mismatch)
          if [ ! -f /config/.web_state_initialized ]; then
            rm -f /config/web.conf \
                  /config/hostlist.conf \
                  /config/hostlist.conf.1.2 \
                  /config/deluge/web.conf \
                  /config/deluge/hostlist.conf \
                  /config/deluge/hostlist.conf.1.2 || true
            : > /config/.web_state_initialized
            chown "$PUID:$PGID" /config/.web_state_initialized
          fi

          # Hand over to original init (linuxserver.io images use s6-overlay).
          exec /init
          EOS
        ]
      }

      # --- Configuration storage volume mount ---
      volume_mount {
        volume      = "deluge-data"
        destination = "/config"
        read_only   = false
      }

      # --- Runtime environment ---
      env {
        PUID                       = "1001"
        PGID                       = "1001"
        TZ                         = "UTC"
        DELUGE_MOVE_COMPLETED_PATH = "/completed"
        DELUGE_MOVE_COMPLETED      = "true"
      }

      # --- Daemon authentication from Vault ---
      template {
        destination = "local/auth"
        perms       = "0600"
        data        = <<-EOH
{{ with secret "kv/data/deluge" }}
localclient:{{ .Data.data.password }}:10
{{ end }}
EOH
      }

      # --- Web UI password from Vault ---
      template {
        destination = "secrets/deluge.env"
        env         = true
        data        = <<-EOENV
{{ with secret "kv/data/deluge" -}}
DELUGE_WEB_PASSWORD={{ .Data.data.web_password }}
{{- end }}
EOENV
      }

      # --- Service registration ---
      service {
        name = "deluge"
        port = "web"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.deluge.rule=Host(`deluge.munchbox`)",
          "traefik.http.routers.deluge.entrypoints=websecure",
          "traefik.http.routers.deluge.tls=true",
          "traefik.http.routers.deluge.middlewares=dashboard-allowlan@file",
          "traefik.http.services.deluge.loadbalancer.server.port=8112",
          "torrent",
          "deluge",
          "downloads"
        ]

        # --- Web UI health check ---
        check {
          name     = "deluge-web"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # --- Resource allocation ---
      resources {
        cpu    = 300
        memory = 256
      }
    }
  }
}
