# -------------------------------------------------------------------------------
#  Waypoint Runner — Nomad Job (token from waypoint-data volume)
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Connects to Waypoint server via TLS with token authentication.
#  Reads bootstrap token from waypoint-data volume (shared with server).
#  Mounts Docker socket for build operations.
# -------------------------------------------------------------------------------

job "waypoint-runner" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  meta {
    version     = "0.11.4"
    owner       = "alex.freidah"
    category    = "development"
    tier        = "tier-2"
    environment = "production"
    description = "Waypoint runner (token from waypoint-data volume, Docker socket mounted)"
  }

  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
  }

  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }

  group "runner" {
    count = 1

    volume "waypoint-data" {
      type      = "host"
      source    = "waypoint-data"
      read_only = true
    }

    volume "docker-socket" {
      type      = "host"
      source    = "docker-socket"
      read_only = false
    }

    network {
      mode = "host"
    }

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

      config {
        image        = "docker-mirror.service.consul:5000/ops-waypoint-image:latest"
        network_mode = "host"
        entrypoint   = []
        args = [
          "sh",
          "-c",
          "export WAYPOINT_SERVER_TOKEN=$(cat /data/waypoint-token) && exec waypoint runner agent",
        ]
      }

      volume_mount {
        volume      = "waypoint-data"
        destination = "/data"
        read_only   = true
      }

      volume_mount {
        volume      = "docker-socket"
        destination = "/var/run/docker.sock"
        read_only   = false
      }

      env {
        TZ                              = "UTC"
        WAYPOINT_SERVER_ADDR            = "mccoy:9701"
        WAYPOINT_SERVER_TLS             = "1"
        WAYPOINT_SERVER_TLS_SKIP_VERIFY = "1"
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
