# -------------------------------------------------------------------------------
# temporal-backup-worker — Munchbox Deployment
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job "temporal-backup-worker" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 50

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------


  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------
  update {
    max_parallel      = 1
    canary            = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }

  # ---------------------------------------------------------------------------
  # Placement
  # ---------------------------------------------------------------------------

  #constraint {
  #  attribute = "${node.unique.name}"
  #  value     = "mccoy"
  #}

  # ---------------------------------------------------------------------------
  # Task Group: worker
  # ---------------------------------------------------------------------------

  group "worker" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
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

    # --- Service Registration ---
    service {
      name     = "temporal-backup-worker"
      provider = "consul"

      tags = [
        "backup",
        "temporal",
      ]

      check {
        name     = "worker-alive"
        type     = "script"
        command  = "/bin/sh"
        args     = ["-c", "pgrep -f temporal-backup-worker"]
        interval = "30s"
        timeout  = "5s"
        task     = "worker"
      }
    }

    # -------------------------------------------------------------------------
    # Task: worker
    # -------------------------------------------------------------------------

    task "worker" {
      driver = "docker"
      user   = "root"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "registry.munchbox.cc/temporal-backup-worker:latest"
        image_pull_timeout = "10m"
        args               = ["worker"]
        network_mode       = "host"
        volumes            = ["/mnt/gdrive:/mnt/gdrive"]
        dns_servers        = ["192.168.68.62", "192.168.68.64"]
      }

      env {
        TEMPORAL_ADDRESS = "192.168.68.61:7233"
        NOMAD_ADDR = "https://nomad.service.consul:4646"
        NOMAD_SKIP_VERIFY = "true"
      }

      template {
        data = <<EOH
{{ with secret "secret/data/backup-worker" }}
NOMAD_TOKEN={{ .Data.data.nomad_token }}
CONSUL_HTTP_TOKEN={{ .Data.data.consul_token }}
VAULT_ADDR=https://vault.service.consul:8200
VAULT_TOKEN={{ .Data.data.vault_token }}
VAULT_SKIP_VERIFY=true
{{ end }}
EOH

        destination = "secrets/backup.env.tpl"
        env         = true
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu    = 100
        memory = 128
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    managed_by             = "nomad-pack"
    "pack.deployment_name" = "munchbox-service"
    "pack.job"             = "temporal-backup-worker"
    "pack.name"            = "munchbox-service"
    "pack.path"            = "/home/afreidah/tools/munchbox/nomad/packs/registry/munchbox-service"
    "pack.registry"        = "<<local folder>>"
    "pack.version"         = "<<none>>"
    project                = "munchbox"
  }
}
