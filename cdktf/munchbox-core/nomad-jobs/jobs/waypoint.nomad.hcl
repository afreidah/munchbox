# -----------------------------------------------------------------------------
# Waypoint - Nomad Job (server + runner)
# - Dedicated Consul token (policy read on system-services/waypoint_server_token)
#   is passed only to the runner's template via `consul_token = "<SECRET_ID>"`
# -----------------------------------------------------------------------------
job "waypoint" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # -----------------------------------------------------------------------------
  # Server group (persistent DB; userns_mode host so bind mount is writable)
  # -----------------------------------------------------------------------------
  group "server" {
    count = 1

    # Force this to run on mccoy
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    # Host volume for DB (declare on each client that may run this)
    # client.hcl:
    #   host_volume "waypoint-data" { path = "/opt/nomad/data/waypoint-data" read_only = false }
    volume "waypoint-data" {
      type      = "host"
      source    = "waypoint-data"
      read_only = false
    }

    # Expose gRPC + UI on static host ports
    network {
      mode = "bridge"
      port "grpc" { static = 9701 }
      port "ui"   { static = 9702 }
    }

    # Register services in Consul using the node's host address (reachable)
    service {
      name         = "waypoint-grpc"
      provider     = "consul"
      port         = "grpc"
      address_mode = "host"
      check {
        name     = "grpc-tcp"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name         = "waypoint-ui"
      provider     = "consul"
      port         = "ui"
      address_mode = "host"
      check {
        name     = "ui-http"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "docker"

      config {
        image        = "hashicorp/waypoint:0.11.4"
        userns_mode  = "host"  # map container root to host root (fixes bind mount perms)
        entrypoint   = ["/bin/sh","-lc"]
        args = [
          "mkdir -p /var/lib/waypoint; exec waypoint server run -accept-tos -db=/var/lib/waypoint/waypoint.db -listen-grpc=0.0.0.0:9701 -listen-http=0.0.0.0:9702"
        ]
        ports = ["grpc","ui"]
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
  }

  # -----------------------------------------------------------------------------
  # Runner group (reads server token from Consul KV via dedicated Consul ACL token)
  # -----------------------------------------------------------------------------
  group "runner" {
    count = 1

    # Force this to run on mccoy
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    network {
      mode = "bridge"
    }

    task "runner" {
      driver = "docker"

      config {
        image      = "hashicorp/waypoint:0.11.4"
        entrypoint = ["/bin/sh","-lc"]
        args = [
          "test -n \"$WAYPOINT_SERVER_TOKEN\" || { echo 'WAYPOINT_SERVER_TOKEN missing'; exit 1; }; exec waypoint runner agent"
        ]
      }

      # Inject token from Consul KV into env using a DEDICATED Consul token that
      # has read access ONLY to key: system-services/waypoint_server_token
      #
      # Replace <CONSUL_SECRET_ID_WAYPOINT_RUNNER_KV_READ> with the SecretID
      # of your 'waypoint-runner-kv-read' Consul token created by CDKTF.
      template {
        destination = "local/env/waypoint.env"
        env         = true
        change_mode = "restart"
        consul_token = "<CONSUL_SECRET_ID_WAYPOINT_RUNNER_KV_READ>"
        data        = "WAYPOINT_SERVER_TOKEN={{ keyOrDefault \"system-services/waypoint_server_token\" \"\" }}"
      }

      # Runner talks to the server via Consul service name (host-registered ports)
      env {
        TZ                   = "America/Los_Angeles"
        WAYPOINT_SERVER_ADDR = "waypoint-grpc.service.consul:9701"
        # Optional if your server uses TLS with a private CA:
        # WAYPOINT_SERVER_TLS             = "1"
        # WAYPOINT_SERVER_TLS_SKIP_VERIFY = "1"
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
