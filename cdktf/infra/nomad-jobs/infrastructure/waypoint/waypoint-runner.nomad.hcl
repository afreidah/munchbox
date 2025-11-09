# -------------------------------------------------------------------------------
#  Waypoint Runner — Nomad Job (reads server token from Vault)
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Runs a Waypoint runner connected to the server via Consul DNS. The runner
#  fetches WAYPOINT_SERVER_TOKEN from Vault at secret/system-services/waypoint_server_token.
# -------------------------------------------------------------------------------

job "waypoint-runner" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # --- Job metadata ---
  meta {
    version     = "0.11.4"
    owner       = "alex.freidah"
    category    = "development"
    tier        = "tier-2"
    environment = "production"
    description = "Waypoint runner that pulls server token from Vault"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
  }

  # --- Placement constraints ---
  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }

  # ---------------------------------------------------------------------------
  #  Runner Group
  # ---------------------------------------------------------------------------

  group "runner" {
    count = 1

    # --- Network configuration ---
    network {
      mode = "bridge"
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
    #  Waypoint Runner Task
    # -----------------------------------------------------------------------

    task "runner" {
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
        image      = "hashicorp/waypoint:0.11.4"
        entrypoint = ["/bin/sh", "-lc"]
        args = [
          "test -n \"$WAYPOINT_SERVER_TOKEN\" || { echo WAYPOINT_SERVER_TOKEN missing; exit 1; }; exec waypoint runner agent"
        ]
      }

      template {
        destination     = "local/env/waypoint.env"
        env             = true
        change_mode     = "restart"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-EOH
[[ with secret "secret/data/system-services/waypoint_server_token" ]]
WAYPOINT_SERVER_TOKEN=[[ .Data.data.token ]]
[[ end ]]
EOH
      }

      env {
        TZ                   = "UTC"
        WAYPOINT_SERVER_ADDR = "192.168.68.63:9701"
      }

      resources {
        cpu    = 300
        memory = 256
      }

      restart {
        attempts = 3
        interval = "30s"
        delay    = "5s"
        mode     = "delay"
      }
    }
  }
}
