# -----------------------------------------------------------------------------
# temporal-config module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the schedules for_each fan-out, the calendar-item mapping, the
# optional-field defaults (namespace=default, overlap_policy=Skip), explicit
# overrides, and the empty-map edge case.
# -----------------------------------------------------------------------------

mock_provider "temporal" {}

variables {
  temporal_host = "mock-temporal.test"

  schedules = {
    "backup-daily" = {
      schedule_id   = "backup-daily"
      hour          = "1"
      workflow_type = "Backup"
      task_queue    = "backup-task-queue"
      workflow_id   = "backup-scheduled"
      input         = "{\"local_days\":7}"
    }
    "registry-gc-weekly" = {
      schedule_id    = "registry-gc-weekly"
      hour           = "2"
      day_of_week    = "0"
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

  # --- schedules output keys on every schedule ---
  assert {
    condition     = toset(keys(output.schedules)) == toset(["backup-daily", "registry-gc-weekly"])
    error_message = "schedules output must key on every schedule"
  }

  # --- schedules output carries schedule_id + defaulted namespace ---
  assert {
    condition     = output.schedules["backup-daily"].schedule_id == "backup-daily" && output.schedules["backup-daily"].namespace == "default"
    error_message = "schedules output must carry schedule_id and defaulted namespace"
  }
}

# -------------------------------------------------------------------------
# calendar: hour maps into spec.calendar_items, day_of_month defaults to 1-31
# -------------------------------------------------------------------------

run "calendar_mapping" {
  command = plan

  # --- hour propagates into the single calendar item ---
  assert {
    condition     = temporal_schedule.this["backup-daily"].spec.calendar_items[0].hour == "1"
    error_message = "hour should map into spec.calendar_items[0].hour"
  }

  # --- unset day_of_month defaults to the server wildcard 1-31 ---
  assert {
    condition     = temporal_schedule.this["backup-daily"].spec.calendar_items[0].day_of_month == "1-31"
    error_message = "day_of_month should default to 1-31 when omitted"
  }

  # --- explicit day_of_week respected (weekly registry GC on Sunday) ---
  assert {
    condition     = temporal_schedule.this["registry-gc-weekly"].spec.calendar_items[0].day_of_week == "0"
    error_message = "explicit day_of_week should be respected"
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
