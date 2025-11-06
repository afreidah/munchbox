# -------------------------------------------------------------------------------
#  Docker Registry Mirror — Docker Image Caching with UI Interface
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Provides Docker Hub image cache via registry:2 mirror for faster pulls
#  across cluster. Runs on goren node with persistent storage. Includes web UI
#  (joxit) for browsing cached images and basic auth for push/pull operations.
#  Exposes registry API on :5000, UI on :5001.
# -------------------------------------------------------------------------------

job "registry" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # --- Job metadata ---
  meta {
    version     = "2.8.3"
    owner       = "alex.freidah"
    category    = "infrastructure"
    tier        = "tier-1"
    environment = "production"
    description = "Docker registry mirror with joxit web UI"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  #  Registry Group
  # ---------------------------------------------------------------------------

  group "mirror" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }

    # --- Registry cache storage volume ---
    volume "registry-data" {
      type      = "host"
      source    = "registry-data"
      read_only = false
    }

    # --- Registry authentication credentials volume ---
    volume "registry-auth" {
      type      = "host"
      source    = "registry-auth"
      read_only = true
    }

    # --- Network configuration ---
    network {
      port "registry" {
        static = 5000
      }
      port "ui" {
        static = 5001
        to     = 80
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
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
    #  Docker Registry Cache Task
    # -----------------------------------------------------------------------

    task "registry" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image              = "registry:2"
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["registry"]
        volumes = [
          "local/config/config.yml:/etc/docker/registry/config.yml"
        ]
      }

      # --- Registry cache storage volume mount ---
      volume_mount {
        volume      = "registry-data"
        destination = "/var/lib/registry"
        read_only   = false
      }

      # --- Registry authentication volume mount ---
      volume_mount {
        volume      = "registry-auth"
        destination = "/auth"
        read_only   = true
      }

      # --- Registry configuration template ---
      template {
        destination = "local/config/config.yml"
        change_mode = "restart"
        perms       = "0644"
        data        = <<-EOT
<<INJECT:files/config.yml>>
EOT
      }

      # --- Runtime environment ---
      env {
        TZ = "UTC"
      }

      # --- Service registration ---
      service {
        name     = "docker-mirror"
        port     = "registry"
        provider = "consul"

        # --- Registry health check ---
        check {
          name     = "registry-api"
          type     = "http"
          path     = "/v2/"
          interval = "10s"
          timeout  = "3s"
        }
      }

      # --- Resource allocation ---
      resources {
        cpu    = 250
        memory = 256
      }
    }

    # -----------------------------------------------------------------------
    #  Registry UI Task
    # -----------------------------------------------------------------------

    task "registry-ui" {
      driver = "docker"

      # --- Workload identity and Vault integration ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker image configuration ---
      config {
        image = "joxit/docker-registry-ui:latest"
        ports = ["ui"]
      }

      # --- Registry credentials template from Vault ---
      template {
        destination = "secrets/registry.env"
        env         = true
        data        = <<-EOH
<<INJECT:files/registry.env>>
EOH
      }

      # --- Runtime environment ---
      env {
        REGISTRY_URL        = "http://goren:5000"
        REGISTRY_TITLE      = "Docker Registry Mirror"
        DELETE_IMAGES       = "false"
        PORT                = "5001"
        REGISTRY_BASIC_AUTH = "true"
        REGISTRY_USERNAME   = "alex.freidah"
      }

      # --- Service registration ---
      service {
        name     = "docker-registry-ui"
        port     = "ui"
        provider = "consul"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.docker-registry-ui.rule=Host(`registry.munchbox`)",
          "traefik.http.routers.docker-registry-ui.entrypoints=websecure",
          "traefik.http.routers.docker-registry-ui.tls=true",
          "traefik.http.routers.docker-registry-ui.middlewares=dashboard-allowlan@file",
          "traefik.http.services.docker-registry-ui.loadbalancer.server.port=5001",
          "docker",
          "registry",
          "ui"
        ]

        # --- Registry UI health check ---
        check {
          name                   = "registry-ui"
          type                   = "http"
          path                   = "/"
          interval               = "15s"
          timeout                = "5s"
          success_before_passing = 1
        }
      }

      # --- Resource allocation ---
      resources {
        cpu    = 150
        memory = 128
      }
    }
  }
}
