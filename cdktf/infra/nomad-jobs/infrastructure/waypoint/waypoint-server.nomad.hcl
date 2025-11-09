# -------------------------------------------------------------------------------
#  Waypoint Server — Nomad Job (gRPC + UI, persistent DB; auto-bootstrap token)
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Runs the Waypoint server with a local SQLite DB on a host volume. Exposes
#  gRPC on :9701 and Web UI on :9702. Registers Consul services (TCP/HTTP checks)
#  and uses bridge networking with static host ports + host address advertising.
#  Poststart task auto-generates a server token and writes it to Vault.
#  NOTE: Ensure the client declares `host_volume "waypoint-data"` on the target node.
# -------------------------------------------------------------------------------

job "waypoint-server" {
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
    description = "Waypoint server (gRPC + UI) with persistent DB; auto-bootstrap token"
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
  #  Server Group
  # ---------------------------------------------------------------------------

  group "server" {
    count = 1

    # --- Persistent volume ---
    volume "waypoint-data" {
      type      = "host"
      source    = "waypoint-data"
      read_only = false
    }

    # --- Network configuration ---
    network {
      mode = "bridge"

      port "grpc" {
        static = 9701
        to     = 9701
      }

      port "ui" {
        static = 9702
        to     = 9702
      }
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

    # --- Service registration: gRPC ---
    service {
      name         = "waypoint-grpc"
      provider     = "consul"
      port         = "grpc"
      address_mode = "host"
      tags         = ["waypoint", "grpc"]
      check {
        name     = "grpc-tcp"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # --- Service registration: UI ---
    service {
      name         = "waypoint-ui"
      provider     = "consul"
      port         = "ui"
      address_mode = "host"
      tags         = ["waypoint", "ui"]
      check {
        name     = "ui-http"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # -----------------------------------------------------------------------
    #  Waypoint Server Task
    # -----------------------------------------------------------------------

    task "server" {
      driver = "docker"
    
      config {
        image       = "docker-mirror.service.consul:5000/ops-waypoint-image:latest"
        userns_mode = "host"
        entrypoint  = ["/bin/sh", "-lc"]
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

    # -----------------------------------------------------------------------
    #  Token Bootstrap Task (poststart: waits for gRPC, writes token to Vault)
    # -----------------------------------------------------------------------

    task "bootstrap-token" {
      driver = "docker"
    
      lifecycle {
        hook = "poststart"
      }
    
      vault {
        role = "nomad-workloads"
      }
    
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }
    
      template {
        destination = "local/bootstrap.sh"
        perms       = "0755"
        change_mode = "noop"
        data        = <<EOH
      <<INJECT:files/bootstrap.sh>>
      EOH
      }
    
      config {
        image      = "docker-mirror.service.consul:5000/ops-waypoint-image:latest"
        entrypoint = ["/bin/bash", "-lc"]
        args       = ["/local/bootstrap.sh"]
      }
    
      env {
        VAULT_ADDR        = "https://192.168.68.63:8200"
        VAULT_SKIP_VERIFY = "true"
      }
    
      resources {
        cpu    = 50
        memory = 64
      }
    
      restart {
        attempts = 1
        interval = "1m"
        delay    = "10s"
        mode     = "fail"
      }
    }

    # -----------------------------------------------------------------------
    #  Pre-Start task to set permissions
    # -----------------------------------------------------------------------

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

