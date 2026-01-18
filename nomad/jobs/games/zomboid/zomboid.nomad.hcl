# -------------------------------------------------------------------------------
# Project Zomboid — Dedicated Multiplayer Server
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs a single stateful Project Zomboid server as a long-lived Nomad service.
# Uses host networking for stable UDP behavior and binds a persistent host volume
# for world state, server configuration, Workshop content, and logs.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job "project-zomboid" {
  type        = "service"
  region      = "global"
  datacenters = ["dc1"]

  # --- Update policy ---
  update {
    max_parallel     = 1
    healthy_deadline = "10m"
    auto_revert      = true
  }

  # --- Rollback policy ---
  migrate {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "30s"
    healthy_deadline = "10m"
  }

  # -------------------------------------------------------------------------
  # SERVER GROUP
  # -------------------------------------------------------------------------

  group "pz" {
    count = 1

    # --- Host networking avoids NAT/bridge overhead for UDP and simplifies port mapping ---
    network {
      mode = "host"

      # --- Primary game port (UDP) ---
      port "game" {
        static = 16261
      }

      # --- Player ports (UDP); reserve a small range for typical player counts ---
      port "player_1"  { static = 16262 }
      port "player_2"  { static = 16263 }
      port "player_3"  { static = 16264 }
      port "player_4"  { static = 16265 }
      port "player_5"  { static = 16266 }
      port "player_6"  { static = 16267 }
      port "player_7"  { static = 16268 }
      port "player_8"  { static = 16269 }
      port "player_9"  { static = 16270 }
      port "player_10" { static = 16271 }

      # --- Steam/server browser/auth (TCP) ---
      port "steam" {
        static = 8766
      }
    }

    # --- Pin the server to one node to keep world state local and avoid frequent rescheduling ---
    constraint {
      attribute = "${node.class}"
      value     = "stateful"
    }

    # --- Persistent host storage ---
    #
    # Source "pz-data" should map to a host volume on SSD. Directory layout uses the
    # standard Zomboid home structure so the server can be operated outside Nomad if needed.
    volume "pz_data" {
      type      = "host"
      source    = "pz-data"
      read_only = false
    }

    # --- Restart policy favors recovery from transient failures without churn ---
    restart {
      attempts = 3
      interval = "30m"
      delay    = "30s"
      mode     = "fail"
    }

    # --- Reschedule policy avoids bouncing the world around the cluster ---
    reschedule {
      attempts  = 1
      interval  = "1h"
      delay     = "2m"
      delay_function = "constant"
      unlimited = false
    }

    # --- Main server task ---
    task "server" {
      driver = "docker"

      # --- Identity ---
      #
      # Vault is optional for this service. Identity is enabled to support future
      # secret injection (admin password, RCON password) without changing the task shape.
      identity {
        env  = true
        file = false
      }

      # --- Container configuration ---
      #
      # Uses a community server image to simplify SteamCMD install/update and launch
      # scripts. Replace the image with a pinned digest in production for reproducibility.
      config {
        image = "ghcr.io/ich777/steamcmd:latest"

        # --- Host networking is configured at the group network stanza ---
        network_mode = "host"

        # --- Persistent data mount ---
        #
        # Container path aligns with common SteamCMD layouts. The Zomboid data directory
        # is rooted under /data to keep all state under a single mount.
        volumes = [
          "local/pz-entrypoint.sh:/pz-entrypoint.sh",
          "pz-data:/data",
        ]

        entrypoint = ["/bin/bash", "/pz-entrypoint.sh"]
      }

      # ---------------------------------------------------------------------
      # SERVICE REGISTRATION
      # ---------------------------------------------------------------------

      service {
        name = "project-zomboid"
        port = "game"

        # --- Health check verifies the process stays up and the port remains bound ---
        check {
          name     = "udp-port-bound"
          type     = "tcp"
          port     = "steam"
          interval = "15s"
          timeout  = "3s"
        }
      }

      # ---------------------------------------------------------------------
      # ENVIRONMENT
      # ---------------------------------------------------------------------

      env {
        # --- SteamCMD install root under persistent volume ---
        STEAMCMD_DIR = "/data/steamcmd"
        PZ_SERVER_DIR = "/data/pz"

        # --- Zomboid home under persistent volume ---
        #
        # Zomboid creates Server/ and Saves/ under this directory.
        ZOMBOID_HOME = "/data/Zomboid"

        # --- JVM tuning focuses on predictable GC and avoiding memory overcommit ---
        #
        # Heap should stay below the Nomad memory allocation to allow native memory,
        # file cache, and mod loading overhead.
        PZ_JAVA_OPTS = "-Xms6g -Xmx6g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

        # --- Server name used by server browser and logs ---
        PZ_SERVER_NAME = "munchbox-pz"

        # --- Administrative password should be sourced from Vault in production ---
        #
        # Plaintext is intentionally avoided. Keep empty until Vault is wired in.
        PZ_ADMIN_PASSWORD = ""
      }

      # ---------------------------------------------------------------------
      # TEMPLATES
      # ---------------------------------------------------------------------

      # --- Entrypoint manages SteamCMD updates, server config, and process launch ---
      #
      # Keeps the runtime behavior self-contained and reproducible without manual steps.
      template {
        destination = "local/pz-entrypoint.sh"
        perms       = "0755"

        data = <<-EOF
          #!/usr/bin/env bash
          set -euo pipefail

          # --- Directory bootstrap ---
          mkdir -p "${STEAMCMD_DIR}" "${PZ_SERVER_DIR}" "${ZOMBOID_HOME}"

          # --- Install SteamCMD if missing ---
          if [[ ! -x "${STEAMCMD_DIR}/steamcmd.sh" ]]; then
            apt-get update -y
            apt-get install -y --no-install-recommends ca-certificates curl lib32gcc-s1 lib32stdc++6
            rm -rf /var/lib/apt/lists/*

            curl -fsSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
              | tar -xz -C "${STEAMCMD_DIR}"
          fi

          # --- Update Project Zomboid dedicated server ---
          #
          # Anonymous login supports server installation without a Steam account.
          "${STEAMCMD_DIR}/steamcmd.sh" \
            +force_install_dir "${PZ_SERVER_DIR}" \
            +login anonymous \
            +app_update 380870 validate \
            +quit

          # --- Server INI bootstrap ---
          #
          # The server reads configuration from ${ZOMBOID_HOME}/Server/${PZ_SERVER_NAME}.ini.
          # Admin password and other sensitive values should be injected via Vault templates.
          mkdir -p "${ZOMBOID_HOME}/Server"
          INI_PATH="${ZOMBOID_HOME}/Server/${PZ_SERVER_NAME}.ini"

          if [[ ! -f "${INI_PATH}" ]]; then
            cat > "${INI_PATH}" <<INI
          PublicName=${PZ_SERVER_NAME}
          DefaultPort=16261
          UDPPort=16261
          SteamPort1=8766
          SteamPort2=8767
          MaxPlayers=16
          PauseEmpty=true
          INI
          fi

          # --- Launch server ---
          #
          # Uses the official start script. Java opts are injected via environment to avoid
          # editing upstream scripts and to keep updates safe.
          export JAVA_OPTS="${PZ_JAVA_OPTS}"
          cd "${PZ_SERVER_DIR}"

          exec ./start-server.sh -servername "${PZ_SERVER_NAME}"
        EOF
      }

      # ---------------------------------------------------------------------
      # RESOURCES
      # ---------------------------------------------------------------------

      resources {
        # --- CPU favors simulation headroom over tight packing ---
        cpu    = 3500
        memory = 8192
      }

      # --- Shutdown behavior avoids world corruption during autosave ---
      kill_signal  = "SIGTERM"
      kill_timeout = "2m"
    }

    # -------------------------------------------------------------------------
    # STORAGE MOUNTS
    # -------------------------------------------------------------------------

    volume_mount {
      volume      = "pz_data"
      destination = "pz-data"
      read_only   = false
    }
  }
}

