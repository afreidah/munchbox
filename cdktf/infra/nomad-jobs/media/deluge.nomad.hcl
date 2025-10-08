# -------------------------------------------------------------------------------
# Deluge BitTorrent Client — Nomad service job
#
# * Runs the Deluge BitTorrent client using the linuxserver/deluge image.
# * Persists configuration and downloads on the host.
# * Exposes web UI on port 8112.
# * Registers service with Consul and configures Traefik for HTTP routing.
# * Routes all Deluge traffic through the WireGuard VPN by running as 'vpnmark'.
#   (Requires host policy routing to mark 'vpnmark' traffic for VPN.)
# -------------------------------------------------------------------------------

job "deluge" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "deluge" {
    count = 1

    constraint {
      # HCL2-safe attribute reference (no interpolation syntax)
      attribute = node.unique.name
      operator  = "="
      value     = "mccoy"
    }

    volume "deluge-data" {
      type      = "host"
      source    = "deluge-data"
      read_only = false
    }

    network {
      mode = "host"
      port "web" { static = 8112 }
    }

    task "deluge" {
      driver = "docker"

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      vault {
        role = "nomad-workloads"
      }

      config {
        image              = "goren:5000/deluge-with-vpnmark:latest"
        image_pull_timeout = "10m"
        ports              = ["web"]
        readonly_rootfs    = false
        cap_add            = ["CHOWN", "FOWNER"]

        # -----------------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------------
        volumes = [
          "/opt/nomad/data/deluge-data/downloads:/downloads",
          "/mnt/gdrive/nomad_deluge_downloads:/completed"
        ]

        # -----------------------------------------------------------------------------
        # PRE-START INIT
        # * Copy the Vault-templated daemon auth from /local/auth into the real
        #   persisted /config/auth with correct ownership/permissions before Deluge starts.
        # * First-run only: Clear stale Web UI state (web.conf/hostlist.conf*), then mark.
        # * Then hand off to linuxserver's s6 init (/init) as usual.
        # -----------------------------------------------------------------------------
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

        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "deluge"
          }
        }
      }

      env = {
        PUID = "1001"
        PGID = "1001"
        TZ   = "UTC"

        # Move completed
        DELUGE_MOVE_COMPLETED_PATH = "/completed"
        DELUGE_MOVE_COMPLETED      = "true"
        # DELUGE_WEB_PASSWORD is provided from Vault via template env below.
      }

      volume_mount {
        volume      = "deluge-data"
        destination = "/config"
        read_only   = false
      }

      # -----------------------------------------------------------------------------
      # VAULT-TEMPLATED DAEMON AUTH
      # * Renders to the allocation as /local/auth (NOT directly under /config).
      # * Pre-start script above copies it into /config/auth atomically (each start).
      # * Format: "localclient:<password>:10" (Deluge 2.x)
      # -----------------------------------------------------------------------------
      template {
        data        = <<EOH
{{ with secret "kv/data/deluge" }}
localclient:{{ .Data.data.password }}:10
{{ end }}
EOH
        destination = "local/auth"
        perms       = "0600"
      }

      # -----------------------------------------------------------------------------
      # VAULT-TEMPLATED WEB UI PASSWORD (ENV)
      # * Sets DELUGE_WEB_PASSWORD from Vault so Web UI login is deterministic.
      # * Expected key: kv/data/deluge -> data.web_password
      # -----------------------------------------------------------------------------
      template {
        env         = true
        destination = "secrets/deluge.env"
        data        = <<EOENV
{{ with secret "kv/data/deluge" -}}
DELUGE_WEB_PASSWORD={{ .Data.data.web_password }}
{{- end }}
EOENV
      }

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
          "downloads",
        ]
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
