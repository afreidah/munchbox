# -----------------------------------------------------------------------------
# Waypoint - Nomad Job (server + runner)
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

    # Pin to mccoy (your persistent disk lives there)
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    # Host volume for DB (declare on the client)
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
      port "ui" { static = 9702 }
    }

    # Consul service: gRPC
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

    # Consul service: UI
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
        image       = "hashicorp/waypoint:0.11.4"
        userns_mode = "host" # keep bind mount writable
        entrypoint  = ["/bin/sh", "-lc"]
        args = [
          "mkdir -p /var/lib/waypoint; exec waypoint server run -accept-tos -db=/var/lib/waypoint/waypoint.db -listen-grpc=0.0.0.0:9701 -listen-http=0.0.0.0:9702"
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
  }

  # -----------------------------------------------------------------------------
  # Runner group (reads server token from Consul KV via a dedicated Consul token)
  # -----------------------------------------------------------------------------
  group "runner" {
    count = 1

    # Pin to mccoy (co-located with server for now)
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

      # -------------------------------------------------------------------------
      # IMPORTANT: give this task a Consul token that can read
      # key "system-services/waypoint_server_token" (read-only policy).
      # This replaces the (unsupported) `consul_token` inside `template {}`.
      # -------------------------------------------------------------------------
      consul {
        token = "<CONSUL_SECRET_ID_WAYPOINT_RUNNER_KV_READ>"
      }

      config {
        image      = "hashicorp/waypoint:0.11.4"
        entrypoint = ["/bin/sh", "-lc"]
        args = [
          "test -n \"$WAYPOINT_SERVER_TOKEN\" || { echo 'WAYPOINT_SERVER_TOKEN missing'; exit 1; }; exec waypoint runner agent"
        ]
      }

      # Pull the server token from Consul KV into env
      template {
        destination = "local/env/waypoint.env"
        env         = true
        change_mode = "restart"
        data        = "WAYPOINT_SERVER_TOKEN={{ keyOrDefault \"system-services/waypoint_server_token\" \"\" }}"
      }

      env {
        TZ                   = "America/Los_Angeles"
        WAYPOINT_SERVER_ADDR = "waypoint-grpc.service.consul:9701"
        # If you later enable TLS on the server with a private CA, you can set:
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

