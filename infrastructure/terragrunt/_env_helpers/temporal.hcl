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
      input         = { local_days = 7, s3_days = 30, dump_concurrency = 4 }
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
      input         = { data_dir = "/opt/nomad/data", grace_days = 7, dry_run = false, docker_prune = true }
    }
    "registry-gc-weekly" = {
      schedule_id   = "registry-gc-weekly"
      year          = "*"
      hour          = "2"
      day_of_week   = "0"
      workflow_type = "RegistryGC"
      task_queue    = "cleanup-task-queue"
      workflow_id   = "registry-gc-scheduled"
      input         = { job_name = "registry", registry_data_dir = "/mnt/gdrive/munchbox-data/registry", registry_image = "registry:3", dry_run = false, delete_untagged = true }
    }
    "aptly-cleanup-weekly" = {
      schedule_id   = "aptly-cleanup-weekly"
      year          = "*"
      hour          = "4"
      day_of_week   = "0"
      workflow_type = "AptlyCleanup"
      task_queue    = "cleanup-task-queue"
      workflow_id   = "aptly-cleanup-scheduled"
      input         = { job_name = "aptly", image = "urpylka/aptly:1.6.2" }
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
  }
}

inputs = {
  temporal_host     = local.temporal_host
  temporal_port     = local.temporal_port
  temporal_insecure = local.temporal_insecure

  schedules = {
    for k, s in local.temporal_schedules :
    k => merge(s, { input = s.input == null ? null : jsonencode(s.input) })
  }
}
