# -------------------------------------------------------------------------------
# MinIO — S3-Compatible Object Storage on OCI Block Volume
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs MinIO in single-drive mode on oracle-arm-1, backed by a 200GB OCI block
# volume mounted at /mnt/minio-data. Exposes S3-compatible storage to the
# cluster via Consul service registration. Credentials are injected from Vault.
# -------------------------------------------------------------------------------

job "minio" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "oracle"
  priority    = 40

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    canary            = 0
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: minio
  # ---------------------------------------------------------------------------

  group "minio" {
    count = 2

    # --- Placement: only run on the OCI ARM nodes that have /mnt/minio-data,
    # one alloc per node (each backed by its own block volume).
    spread {
      attribute = "${node.unique.name}"
    }

    constraint {
      attribute = "${node.unique.name}"
      operator  = "regexp"
      value     = "^oraclearm[12]$"
    }

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    # --- Network Configuration ---
    network {
      mode = "host"
      port "api" {
        static = 9010
      }
      port "console" {
        static = 9011
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # --- Service Registration (S3 API, shared name — round-robins both allocs) ---
    service {
      name     = "minio"
      port     = "api"
      provider = "consul"

      tags = [
        "infrastructure",
        "storage",
        "minio",
        "node-${node.unique.name}",
      ]

      check {
        name      = "minio-health"
        type      = "http"
        path      = "/minio/health/live"
        port      = "api"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # --- Service Registration (S3 API, per-node — for explicit addressing
    # by clients that treat each instance as a distinct backend). ---
    service {
      name     = "minio-${node.unique.name}"
      port     = "api"
      provider = "consul"

      tags = [
        "infrastructure",
        "storage",
        "minio",
      ]

      check {
        name      = "minio-${node.unique.name}-health"
        type      = "http"
        path      = "/minio/health/live"
        port      = "api"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # --- Service Registration (Console, per-node — distinct URL per instance) ---
    service {
      name     = "minio-console-${node.unique.name}"
      port     = "console"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.minio-console-${node.unique.name}.rule=Host(`minio-${node.unique.name}.munchbox.cc`)",
        "traefik.http.routers.minio-console-${node.unique.name}.entrypoints=websecure",
        "traefik.http.routers.minio-console-${node.unique.name}.tls=true",
        "traefik.http.services.minio-console-${node.unique.name}.loadbalancer.server.port=9011",
        "traefik.http.routers.minio-console-${node.unique.name}.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
        "traefik.http.routers.minio-console-${node.unique.name}-http.rule=Host(`minio-${node.unique.name}.munchbox.cc`)",
        "traefik.http.routers.minio-console-${node.unique.name}-http.entrypoints=web",
        "traefik.http.routers.minio-console-${node.unique.name}-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file",
      ]

      check {
        name      = "minio-console-${node.unique.name}-health"
        type      = "http"
        path      = "/minio/health/live"
        port      = "api"
        interval  = "10s"
        timeout   = "3s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: minio
    # -------------------------------------------------------------------------

    task "minio" {
      driver = "docker"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image              = "minio/minio:RELEASE.2025-09-07T16-13-09Z"
        image_pull_timeout = "10m"
        ports              = ["api", "console"]
        network_mode       = "host"
        args = [
          "server", "/data",
          "--address", "0.0.0.0:9010",
          "--console-address", "0.0.0.0:9011",
        ]
        volumes = [
          "/mnt/minio-data:/data",
        ]
      }

      # --- Environment (credentials from Vault) ---
      template {
        data        = <<EOH
{{ with secret "secret/data/minio" }}
MINIO_ROOT_USER={{ .Data.data.root_user }}
MINIO_ROOT_PASSWORD={{ .Data.data.root_password }}
{{ end }}
EOH
        destination = "secrets/env"
        env         = true
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu        = 512
        memory     = 512
        memory_max = 1024
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
