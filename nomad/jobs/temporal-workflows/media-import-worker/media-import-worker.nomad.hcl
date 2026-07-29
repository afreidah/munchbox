# -------------------------------------------------------------------------------
# Media Import Worker - Temporal Download Reconciler
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal worker that reconciles completed Deluge downloads grabbed outside
# Sonarr/Radarr into the media library so Jellyfin can see them. Listens on the
# media-import-task-queue; the Reconcile workflow is started on a schedule by a
# Temporal Schedule. Pulls its Sonarr/Radarr/Deluge/Jellyfin credentials from
# Vault via its Nomad Workload Identity -- no static secrets in the job.
# -------------------------------------------------------------------------------

job "media-import-worker" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 40

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------
  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Placement - needs LAN access to the media services (sonarr/radarr/deluge/
  # jellyfin on the home LAN), so keep it off the Oracle cloud nodes.
  # ---------------------------------------------------------------------------
  constraint {
    attribute = "${meta.cloud}"
    operator  = "!="
    value     = "oracle"
  }

  # ---------------------------------------------------------------------------
  # Task Group: worker
  # ---------------------------------------------------------------------------
  group "worker" {
    count = 1

    network {
      # --- Dynamic host port (host networking): the worker binds it via
      #     METRICS_LISTEN below, so the check hits the same port and it never
      #     collides with the node's :9090. ---
      port "metrics" {}
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "10s"
      delay_function = "exponential"
      max_delay      = "2m"
      unlimited      = false
    }

    # --- Service registration for Prometheus scraping ---
    service {
      name     = "media-import-worker"
      port     = "metrics"
      provider = "consul"
      tags = [
        "temporal",
        "media",
        "traefik.enable=false",
      ]
      # --- HTTP check on /metrics: the unified-build entrypoint is `worker`
      #     and the distroless runtime ships no pgrep, so a live /metrics is
      #     the liveness signal (matches the other WI workers). ---
      check {
        name      = "metrics"
        type      = "http"
        port      = "metrics"
        path      = "/metrics"
        interval  = "30s"
        timeout   = "5s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: media-import-worker
    # -------------------------------------------------------------------------
    task "media-import-worker" {
      driver = "docker"

      # --- WI: the nomad-workloads role grants read on secret/{media-import,
      #     deluge,jellyfin}; the worker reads them through its own Vault client. ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "registry.munchbox.cc/media-import-worker:latest"
        force_pull         = true
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["metrics"]
        volumes = [
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/vault-ca.pem:ro",
        ]
      }

      env {
        TEMPORAL_ADDRESS            = "temporal-server.service.consul:7233"
        VAULT_ADDR                  = "https://vault.service.consul:8200"
        VAULT_CACERT                = "/etc/ssl/certs/vault-ca.pem"
        VAULT_TOKEN_FILE            = "/secrets/vault_token"
        SONARR_ADDR                 = "http://sonarr.service.consul:8989"
        RADARR_ADDR                 = "http://radarr.service.consul:7878"
        DELUGE_ADDR                 = "http://deluge.service.consul:8112"
        JELLYFIN_ADDR               = "http://jellyfin.service.consul:8096"
        METRICS_LISTEN              = ":${NOMAD_PORT_metrics}"
        OTEL_EXPORTER_OTLP_ENDPOINT = "tempo.service.consul:4317"
      }

      # --- Light: bounded HTTP calls to the media services; no local unpacking. ---
      resources {
        cpu    = 200
        memory = 256
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    project = "munchbox"
  }
}
