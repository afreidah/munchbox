# -----------------------------------------------------------------------------
# TEMPORAL ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the temporal-config module. Holds the frontend connection and
# the schedule definitions, and json-encodes each schedule's input object into
# the workflow argument payload the provider expects (null input passes through
# untouched).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//temporal-config"
}

locals {
  # --- in-cluster frontend; plaintext gRPC (no mTLS), so insecure = true ---
  temporal_host     = "temporal-server.service.consul"
  temporal_port     = "7233"
  temporal_insecure = true

  # --- Namespaces, one per worker domain. The UI lists executions per
  #     namespace, and retention is set per namespace, so a domain's volume no
  #     longer decides how long every other domain's history is kept.
  #
  #     Nothing is left in `default`, so it stays unmanaged rather than being
  #     imported into state. ---
  temporal_namespaces = {
    "ci" = {
      owner_email    = "alex.freidah@gmail.com"
      description    = "Runner scaling and image reconciliation."
      retention_days = 1 # the provider's floor, and more than anyone reads
    }
    "backup" = {
      owner_email    = "alex.freidah@gmail.com"
      description    = "Database and volume backups."
      retention_days = 30
    }
    "maintenance" = {
      owner_email    = "alex.freidah@gmail.com"
      description    = "Cleanup, registry GC, aptly pruning, Postgres maintenance."
      retention_days = 30
    }
    "security" = {
      owner_email    = "alex.freidah@gmail.com"
      description    = "Trivy image scanning."
      retention_days = 30
    }
    "certs" = {
      owner_email    = "alex.freidah@gmail.com"
      description    = "Certificate acquisition and renewal."
      retention_days = 90 # weekly cadence; 90d covers a dozen cycles
    }
    "tokens" = {
      owner_email    = "alex.freidah@gmail.com"
      description    = "GitHub App and SonarCloud token renewal."
      retention_days = 30
    }
    "media" = {
      owner_email    = "alex.freidah@gmail.com"
      description    = "Media library reconciliation."
      retention_days = 7
    }
  }

  queue_namespaces = {
    "backup-task-queue"               = "backup"
    "trivy-task-queue"                = "security"
    "cleanup-task-queue"              = "maintenance"
    "cert-task-queue"                 = "certs"
    "github-token-renewer-task-queue" = "tokens"
    "ci-runner-scaler-task-queue"     = "ci"
    "media-import-task-queue"         = "media"
  }

  # --- map key = TF state key; input is the workflow argument object (json-
  #     encoded below, null = no argument). schedules use the calendar form
  #     (not a cron string): it is what the provider stores and reads back, so
  #     re-plans converge. ---
  temporal_schedules = {
    "backup-daily" = {
      schedule_id   = "backup-daily"
      year          = "*"
      hour          = "1"
      workflow_type = "Backup"
      task_queue    = "backup-task-queue"
      workflow_id   = "backup-scheduled"
      # s3_cleanup = false: uploads are tagged (backup=nomad|consul|postgres,
      # plus database=<name>), so S3 retention belongs in s3-orchestrator
      # lifecycle rules that expire per backup type. s3_days is omitted because
      # the workflow only reads it when the sweep is on. Nothing expires S3
      # backups until those lifecycle rules exist.
      input = { local_days = 7, s3_cleanup = false, dump_concurrency = 4 }
    }
    "trivy-daily" = {
      schedule_id   = "trivy-daily"
      year          = "*"
      hour          = "3"
      workflow_type = "Scan"
      task_queue    = "trivy-task-queue"
      workflow_id   = "trivy-scheduled"
      input         = { concurrency = 10 }
    }
    "cleanup-daily" = {
      schedule_id   = "cleanup-daily"
      year          = "*"
      hour          = "5"
      workflow_type = "Cleanup"
      task_queue    = "cleanup-task-queue"
      workflow_id   = "cleanup-scheduled"
      input         = { data_dir = "/opt/nomad/data", grace_days = 7, dry_run = false, docker_prune = true, containerd_prune = true, rootfs_prune = true, buildx_volume_prune = true }
    }
    "registry-gc-weekly" = {
      schedule_id   = "registry-gc-weekly"
      year          = "*"
      hour          = "2"
      day_of_week   = "0"
      workflow_type = "RegistryGC"
      task_queue    = "cleanup-task-queue"
      workflow_id   = "registry-gc-scheduled"
      # registry_image must match the tag the registry job runs (registry.hcl)
      # -- the GC activity requires the image already present locally, no pull.
      input = { job_name = "registry", registry_data_dir = "/mnt/gdrive/munchbox-data/registry", registry_image = "registry:3.1.1", dry_run = false, delete_untagged = true }
    }
    "aptly-cleanup-weekly" = {
      schedule_id   = "aptly-cleanup-weekly"
      year          = "*"
      hour          = "4"
      day_of_week   = "0"
      workflow_type = "AptlyCleanup"
      task_queue    = "cleanup-task-queue"
      workflow_id   = "aptly-cleanup-scheduled"
      input         = { job_name = "aptly" }
    }
    "postgres-maintenance-weekly" = {
      schedule_id   = "postgres-maintenance-weekly"
      year          = "*"
      hour          = "6"
      day_of_week   = "0"
      workflow_type = "PostgresMaintenance"
      task_queue    = "cleanup-task-queue"
      workflow_id   = "postgres-maintenance-scheduled"
      input         = { concurrency = 2 }
    }
    "cert-acquirer-weekly" = {
      schedule_id   = "cert-acquirer-weekly"
      year          = "*"
      hour          = "4"
      day_of_week   = "1"
      workflow_type = "CertAcquirer"
      task_queue    = "cert-task-queue"
      workflow_id   = "cert-acquirer-scheduled"
      input         = { domains = ["*.munchbox.cc", "munchbox.cc"], email = "alex@alexfreidah.com" }
    }
    # Every 30 min so the 1-hour GitHub App tokens it writes are always fresh
    # (the secret is never older than 30 min vs. a 60 min token life).
    "github-token-renewer-30min" = {
      schedule_id   = "github-token-renewer-30min"
      hour          = "*"
      minute        = "0,30"
      workflow_type = "RenewTokens"
      task_queue    = "github-token-renewer-task-queue"
      workflow_id   = "github-token-renewer-scheduled"
      input         = { concurrency = 4 }
    }
    # Weekly: SonarCloud analysis tokens are long-lived (90-day TTL), so they only
    # need slow rotation for hygiene -- not the 30-min cadence the GitHub tokens
    # require. Same worker/task queue, different workflow.
    "sonarcloud-token-renewer-weekly" = {
      schedule_id   = "sonarcloud-token-renewer-weekly"
      year          = "*"
      hour          = "7"
      day_of_week   = "0"
      workflow_type = "RenewSonarCloudTokens"
      task_queue    = "github-token-renewer-task-queue"
      workflow_id   = "sonarcloud-token-renewer-scheduled"
      input         = { concurrency = 4 }
    }
    # Every 30s (second-level calendar, since the provider stores calendars not
    # intervals): poll GitHub for queued self-hosted jobs and dispatch ephemeral
    # runners. Overlap Skip (the default) keeps a slow tick from stacking.
    "ci-runner-scaler-30s" = {
      schedule_id   = "ci-runner-scaler-30s"
      hour          = "*"
      minute        = "*"
      second        = "0,30"
      workflow_type = "PollAndDispatch"
      task_queue    = "ci-runner-scaler-task-queue"
      workflow_id   = "ci-runner-scaler-scheduled"
      input         = { concurrency = 4 }
    }
    # Every 2 hours: reconcile completed Deluge downloads (grabbed outside
    # Sonarr/Radarr) into the library so Jellyfin picks them up.
    "media-reconcile" = {
      schedule_id   = "media-reconcile"
      year          = "*"
      hour          = "0,2,4,6,8,10,12,14,16,18,20,22"
      workflow_type = "Reconcile"
      task_queue    = "media-import-task-queue"
      workflow_id   = "media-reconcile-scheduled"
      input         = { concurrency = 4, dry_run = false }
    }
  }
}

inputs = {
  temporal_host     = local.temporal_host
  temporal_port     = local.temporal_port
  temporal_insecure = local.temporal_insecure

  namespaces = local.temporal_namespaces

  # Namespace is derived from the task queue rather than spelled out per
  # schedule: one worker serves a queue and one namespace holds that worker, so
  # naming it on each entry would only be a chance to get it wrong.
  schedules = {
    for k, s in local.temporal_schedules :
    k => merge(s, {
      namespace = local.queue_namespaces[s.task_queue]
      input     = s.input == null ? null : jsonencode(s.input)
    })
  }
}
