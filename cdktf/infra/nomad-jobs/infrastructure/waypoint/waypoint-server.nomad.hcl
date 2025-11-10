# -------------------------------------------------------------------------------
#  Waypoint Server — Nomad Job (no auth, local dev)
#
#  Project: Munchbox
#  Author: Alex Freidah
# -------------------------------------------------------------------------------

job "waypoint-server" {
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
    description = "Waypoint server (local dev, no auth)"
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

  group "server" {
    count = 1

    volume "waypoint-data" {
      type      = "host"
      source    = "waypoint-data"
      read_only = false
    }

    network {
      mode = "host"

      port "grpc" {
        static = 9701
        to     = 9701
      }

      port "ui" {
        static = 9702
        to     = 9702
      }
    }

    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    service {
      name         = "waypoint-grpc"
      provider     = "consul"
      port         = "grpc"
      address_mode = "host"
      tags         = ["waypoint", "grpc"]
      #check {
      #  name     = "grpc-tcp"
      #  type     = "tcp"
      #  interval = "10s"
      #  timeout  = "2s"
      #}
    }

    service {
      name         = "waypoint-ui"
      provider     = "consul"
      port         = "ui"
      address_mode = "host"
      tags         = ["waypoint", "ui"]
      #check {
      #  name     = "ui-http"
      #  type     = "http"
      #  path     = "/"
      #  interval = "10s"
      #  timeout  = "2s"
      #}
    }

    task "server" {
      driver = "docker"

      config {
        image        = "docker-mirror.service.consul:5000/ops-waypoint-image:latest"
        network_mode = "host"
        entrypoint   = ["/bin/sh", "-lc"]
        args = [
          "mkdir -p /var/lib/waypoint && exec waypoint server run -accept-tos -db=/var/lib/waypoint/waypoint.db -listen-grpc=0.0.0.0:9701 -listen-http=0.0.0.0:9702"
        ]
        ports = ["grpc", "ui"]
      }

      volume_mount {
        volume      = "waypoint-data"
        destination = "/var/lib/waypoint"
        read_only   = false
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

    task "fix-perms" {
      driver = "docker"
      lifecycle {
        hook = "prestart"
      }

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
    }
  }
}
