# -------------------------------------------------------------------------------
# Immich — Self-hosted Photo and Video Management
#
# Project: Munchbox / Author: Alex Freidah
#
# High-performance photo backup and management platform with machine learning
# capabilities for face recognition, object detection, and smart search. Uses
# existing Patroni PostgreSQL (with pgvector) and Redis Sentinel for storage
# and caching. Photos stored on shared NFS mount for cluster-wide access.
#
# Components: Server (API/Web) + Machine Learning (CUDA-accelerated)
# Placement: On-prem nodes only, prefers GPU-enabled node (nomad-client-04)
# -------------------------------------------------------------------------------

job "immich" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "default"

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
    tier       = "tier-2"
  }

  # ---------------------------------------------------------------------------
  # Placement — On-prem only, prefer GPU node
  # ---------------------------------------------------------------------------

  # Exclude Oracle cloud nodes
  constraint {
    attribute = "${meta.cloud}"
    operator  = "!="
    value     = "oracle"
  }

  # Strong preference for nomad-client-04 (has NVIDIA GPU)
  affinity {
    attribute = "${node.unique.name}"
    value     = "nomad-client-04"
    weight    = 100
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: immich
  # ---------------------------------------------------------------------------

  group "immich" {
    count = 1

    network {
      mode = "bridge"
      port "http" { to = 2283 }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    # --- Service Registration ---
    service {
      name     = "immich"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.immich.rule=Host(`photos.munchbox.cc`)",
        "traefik.http.routers.immich.entrypoints=websecure",
        "traefik.http.routers.immich.tls=true",
        "traefik.http.services.immich.loadbalancer.server.port=2283",
        "media",
        "photos"
      ]

      check {
        name     = "immich-health"
        type     = "http"
        path     = "/api/server-info/ping"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: init-storage
    # -------------------------------------------------------------------------

    task "init-storage" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image   = "busybox:1.37.0"
        command = "sh"
        args = ["-c", <<-EOF
          mkdir -p /library/upload /library/library /library/thumbs /library/encoded-video /library/profile
          mkdir -p /cache
          chown -R 1000:1000 /library /cache
          chmod -R 755 /library /cache
        EOF
        ]
        volumes = [
          "/mnt/gdrive/immich:/library",
          "/mnt/gdrive/immich/model-cache:/cache"
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    # -------------------------------------------------------------------------
    # Task: server
    # -------------------------------------------------------------------------

    task "server" {
      driver = "docker"

      config {
        image = "ghcr.io/immich-app/immich-server:release"

        volumes = [
          "/mnt/gdrive/immich:/usr/src/app/upload",
          "/etc/localtime:/etc/localtime:ro"
        ]

        # DNS for Consul service discovery
        dns_servers = ["172.17.0.1"]
      }

      # --- Vault Identity ---
      identity {
        env  = true
        file = false
      }

      vault {}

      # --- Environment from Vault ---
      template {
        destination = "secrets/env.env"
        env         = true
        change_mode = "restart"
        data        = <<-EOF
{{ with secret "secret/data/immich" }}
DB_USERNAME={{ .Data.data.db_username }}
DB_PASSWORD={{ .Data.data.db_password }}
DB_DATABASE_NAME=immich
{{ end }}
DB_HOSTNAME=postgres-primary.service.consul
DB_PORT=5432

REDIS_HOSTNAME=redis-primary.service.consul
REDIS_PORT=6379
{{ with secret "secret/data/redis" }}
REDIS_PASSWORD={{ .Data.data.password }}
{{ end }}

IMMICH_MACHINE_LEARNING_URL=http://localhost:3003
UPLOAD_LOCATION=/usr/src/app/upload
TZ=America/Los_Angeles
        EOF
      }

      resources {
        cpu    = 512
        memory = 1024
      }
    }

    # -------------------------------------------------------------------------
    # Task: machine-learning (CUDA-accelerated)
    # -------------------------------------------------------------------------

    task "machine-learning" {
      driver = "docker"

      config {
        image   = "ghcr.io/immich-app/immich-machine-learning:release-cuda"
        runtime = "nvidia"

        # NVIDIA GPU device passthrough
        devices = [
          { host_path = "/dev/nvidia0", container_path = "/dev/nvidia0" },
          { host_path = "/dev/nvidiactl", container_path = "/dev/nvidiactl" },
          { host_path = "/dev/nvidia-uvm", container_path = "/dev/nvidia-uvm" },
          { host_path = "/dev/nvidia-uvm-tools", container_path = "/dev/nvidia-uvm-tools" }
        ]

        volumes = [
          "/mnt/gdrive/immich/model-cache:/cache",
          "/etc/localtime:/etc/localtime:ro"
        ]
      }

      # --- Vault Identity ---
      identity {
        env  = true
        file = false
      }

      vault {}

      env {
        MACHINE_LEARNING_CACHE_FOLDER = "/cache"
        TZ                            = "America/Los_Angeles"
        # CUDA settings
        NVIDIA_VISIBLE_DEVICES        = "all"
        NVIDIA_DRIVER_CAPABILITIES    = "compute,utility"
      }

      # ML processing with GPU - can use less CPU but still needs RAM for models
      resources {
        cpu    = 1000
        memory = 4096
      }
    }
  }
}
