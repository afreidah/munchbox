# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Waypoint Data Permission Fix — Standalone Job
#
# One-time batch job to ensure waypoint-data volume has correct permissions
# before the server starts. Run this once manually or add to deployment pipeline.
# -------------------------------------------------------------------------------

job "waypoint-fix-perms" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "batch"
  node_pool   = "core"

  meta {
    managed_by = "manual"
    project    = "munchbox"
    tier       = "utility"
  }

  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }

  group "fix" {
    count = 1

    volume "waypoint-data" {
      type      = "host"
      source    = "waypoint-data"
      read_only = false
    }

    task "fix-perms" {
      driver = "docker"

      config {
        image   = "alpine:3.20"
        command = "sh"
        args    = ["-c", "mkdir -p /var/lib/waypoint && chown -R 10001:10001 /var/lib/waypoint && ls -ld /var/lib/waypoint"]
      }

      volume_mount {
        volume      = "waypoint-data"
        destination = "/var/lib/waypoint"
        read_only   = false
      }

      resources {
        cpu    = 50
        memory = 64
      }

      restart {
        attempts = 1
        interval = "1m"
        delay    = "5s"
        mode     = "fail"
      }
    }
  }
}
