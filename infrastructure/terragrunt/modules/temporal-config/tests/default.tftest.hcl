# -----------------------------------------------------------------------------
# temporal-config module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the schedules for_each fan-out, the cron-to-cron_items wrapping, the
# optional-field defaults (namespace=default, overlap_policy=Skip), explicit
# overrides, and the empty-map edge case.
# -----------------------------------------------------------------------------

mock_provider "temporal" {}

variables {
  temporal_host = "mock-temporal.test"

  schedules = {
    "backup-daily" = {
      schedule_id   = "backup-daily"
      cron          = "0 1 * * *"
      workflow_type = "Backup"
      task_queue    = "backup-task-queue"
      workflow_id   = "backup-scheduled"
      input         = "{\"local_days\":7}"
    }
    "registry-gc-weekly" = {
      schedule_id    = "registry-gc-weekly"
      cron           = "0 2 * * 0"
      workflow_type  = "RegistryGC"
      task_queue     = "cleanup-task-queue"
      workflow_id    = "registry-gc-scheduled"
      overlap_policy = "BufferOne"
    }
  }
}

# -------------------------------------------------------------------------
# schedules for_each: one resource per map key
# -------------------------------------------------------------------------

run "schedules_for_each" {
  command = plan

  # --- two schedule inputs -> two resources ---
  assert {
    condition     = length(temporal_schedule.this) == 2
    error_message = "two schedules inputs -> two resources"
  }

  # --- schedule_id propagates from map value ---
  assert {
    condition     = temporal_schedule.this["backup-daily"].schedule_id == "backup-daily"
    error_message = "schedule_id should propagate from the map value"
  }
}

# -------------------------------------------------------------------------
# cron wraps into spec.cron_items
# -------------------------------------------------------------------------

run "cron_wrapping" {
  command = plan

  # --- single cron string becomes a one-element cron_items list ---
  assert {
    condition     = temporal_schedule.this["backup-daily"].spec.cron_items == tolist(["0 1 * * *"])
    error_message = "cron should wrap into a single-element spec.cron_items list"
  }
}

# -------------------------------------------------------------------------
# defaults: namespace=default, overlap_policy=Skip when omitted
# -------------------------------------------------------------------------

run "optional_defaulting" {
  command = plan

  # --- namespace defaults to "default" when omitted ---
  assert {
    condition     = temporal_schedule.this["backup-daily"].namespace == "default"
    error_message = "namespace should default to default when omitted"
  }

  # --- overlap_policy defaults to Skip when omitted ---
  assert {
    condition     = temporal_schedule.this["backup-daily"].policy_config.overlap_policy == "Skip"
    error_message = "overlap_policy should default to Skip when omitted"
  }

  # --- explicit overlap_policy respected ---
  assert {
    condition     = temporal_schedule.this["registry-gc-weekly"].policy_config.overlap_policy == "BufferOne"
    error_message = "explicit overlap_policy should be respected"
  }
}

# -------------------------------------------------------------------------
# Empty inputs edge case: zero schedules
# -------------------------------------------------------------------------

run "empty_inputs" {
  command = plan

  variables {
    schedules = {}
  }

  # --- empty schedules -> zero resources ---
  assert {
    condition     = length(temporal_schedule.this) == 0
    error_message = "empty schedules -> zero resources"
  }
}
