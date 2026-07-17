# -------------------------------------------------------------------------------
# Deluge — BitTorrent Client with VPN
#
# Project: Munchbox / Author: Alex Freidah
#
# Deluge torrent client routed through gluetun VPN (PIA) for privacy.
# Gluetun creates VPN tunnel, Deluge shares its network namespace.
# All torrent traffic goes through the VPN tunnel.
# -------------------------------------------------------------------------------

job "deluge" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"

  # ---------------------------------------------------------------------------
  # Placement - pin to node with /tank storage
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${meta.gpu}"
    operator  = "="
    value     = "true"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group
  # ---------------------------------------------------------------------------

  group "deluge" {
    count = 1

    network {
      mode = "bridge"
      port "web" {
        static = 8112
        to     = 8112
      }
      port "torrent" {
        static = 6881
        to     = 6881
      }
      port "gluetun" {
        static = 8000
        to     = 8000
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    # --- Service Registration (points to gluetun's exposed port) ---
    service {
      name     = "deluge"
      provider = "consul"
      port     = 8112
      address  = "${attr.unique.network.ip-address}"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.deluge.rule=Host(`deluge.munchbox.cc`)",
        "traefik.http.routers.deluge.entrypoints=websecure",
        "traefik.http.routers.deluge.tls=true",
        "traefik.http.routers.deluge.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
        "traefik.http.services.deluge.loadbalancer.server.port=8112",
        "traefik.http.routers.deluge-http.rule=Host(`deluge.munchbox.cc`)",
        "traefik.http.routers.deluge-http.entrypoints=web",
        "traefik.http.routers.deluge-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file",
        "deluge",
        "torrent",
        "media"
      ]

      check {
        name     = "deluge-health"
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }

      check {
        name     = "vpn-tunnel"
        type     = "http"
        port     = "gluetun"
        path     = "/v1/vpn/status"
        interval = "30s"
        timeout  = "5s"

        check_restart {
          limit = 3
          grace = "90s"
        }
      }
    }

    # -------------------------------------------------------------------------
    # Task: cleanup-vpn (remove stale tun/wg interfaces from prior dirty exit)
    # -------------------------------------------------------------------------

    task "cleanup-vpn" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image        = "alpine:3.23.5"
        privileged   = true
        network_mode = "host"
        command      = "/bin/sh"
        args         = ["-c", "ip link delete tun0 2>/dev/null; ip link delete wg0 2>/dev/null; true"]

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
        ]
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    # -------------------------------------------------------------------------
    # Task: gluetun (VPN tunnel - exposes ports for deluge)
    # -------------------------------------------------------------------------

    task "gluetun" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image      = "qmcgaw/gluetun:v3.41.1"
        privileged = true

        cap_add = ["NET_ADMIN"]

        ports = ["web", "torrent", "gluetun"]

        devices = [
          {
            host_path      = "/dev/net/tun"
            container_path = "/dev/net/tun"
          }
        ]
      }

      # Mullvad VPN credentials from Vault (WireGuard - OpenVPN certs expired)
      template {
        data        = <<-EOF
VPN_SERVICE_PROVIDER=mullvad
VPN_TYPE=wireguard
{{- with secret "secret/data/mullvad" }}
WIREGUARD_PRIVATE_KEY={{ .Data.data.wg_private_key }}
WIREGUARD_ADDRESSES={{ .Data.data.wg_address }}
{{- end }}
SERVER_CITIES=Los Angeles CA
FIREWALL_VPN_INPUT_PORTS=6881
FIREWALL_OUTBOUND_SUBNETS=192.168.68.0/24,10.200.0.0/24
HTTP_CONTROL_SERVER_ADDRESS=:8000
TZ=America/Los_Angeles
EOF
        destination = "secrets/gluetun.env"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 192
      }
    }

    # -------------------------------------------------------------------------
    # Task: deluge (uses gluetun's network namespace)
    # -------------------------------------------------------------------------

    task "deluge" {
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
        image = "linuxserver/deluge:2.2.0"

        # Bridge mode shares network with gluetun sidecar - all traffic routes through VPN

        # deluge download_location/move_completed_path (in the app-owned core.conf,
        # not templatable here) MUST be /data/torrents -- i.e. under this /tank:/data
        # mount. Same mount layout as the *arr apps so imports hardlink instead of copy.
        volumes = [
          "/opt/nomad/data/deluge:/config",
          "/tank:/data",
          "local/web.conf:/config/web.conf"
        ]
      }

      # Web UI config with password from Vault
      template {
        destination = "local/web.conf"
        data        = <<-EOF
{
    "file": 3,
    "format": 1
}{
    "base": "/",
    "cert": "ssl/daemon.cert",
    "default_daemon": "",
    "enabled_plugins": [],
    "first_login": false,
    "https": false,
    "interface": "0.0.0.0",
    "language": "",
    "pkey": "ssl/daemon.pkey",
    "port": 8112,
{{ with secret "secret/data/deluge" }}
    "pwd_salt": "{{ .Data.data.pwd_salt }}",
    "pwd_sha1": "{{ .Data.data.pwd_sha1 }}",
{{ end }}
    "session_timeout": 3600,
    "show_session_speed": false,
    "show_sidebar": true,
    "sidebar_multiple_filters": true,
    "sidebar_show_zero": false,
    "theme": "gray"
}
        EOF
      }

      env {
        PUID               = "1001"
        PGID               = "1001"
        TZ                 = "America/Los_Angeles"
        DOCKER_MODS        = "ghcr.io/themepark-dev/theme.park:deluge"
        TP_COMMUNITY_THEME = "true"
        TP_THEME           = "catppuccin-mocha"
      }

      resources {
        cpu = 1500
        # 192 MiB OOM-killed deluged every ~1-2 min with 100+ torrents (lost
        # WebUI connection + reset download state on each kill). Burst to 1 GiB.
        memory     = 512
        memory_max = 1024
      }

      kill_timeout = "30s"
    }
  }
}
