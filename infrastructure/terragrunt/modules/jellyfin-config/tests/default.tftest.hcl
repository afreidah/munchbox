# -----------------------------------------------------------------------------
# jellyfin-config module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the singleton count-gating (a config renders one resource when its
# JSON is set, zero when null), the configuration_json pass-through, the
# scheduled_tasks for_each fan-out, and the all-empty edge case.
# -----------------------------------------------------------------------------

mock_provider "jellyfin" {}

variables {
  jellyfin_endpoint = "http://mock-jellyfin.test:8096"
  jellyfin_api_key  = "mock-api-key"

  encoding_configuration_json = "{\"EnableHardwareEncoding\":true,\"H264Crf\":23}"
  livetv_configuration_json   = "{\"PrePaddingSeconds\":120,\"TunerHosts\":[],\"ListingProviders\":[]}"

  scheduled_tasks = {
    "guide-refresh" = {
      task_id       = "a558367c153e8b2ca2b0f9d4f5f8e6c1"
      triggers_json = "[{\"Type\":\"IntervalTrigger\",\"IntervalTicks\":432000000000}]"
    }
    "scan-library" = {
      task_id       = "7738148ffcd07979c7ceb148e06b3aed"
      triggers_json = "[{\"Type\":\"DailyTrigger\",\"TimeOfDayTicks\":0}]"
    }
  }
}

# -------------------------------------------------------------------------
# Singleton configs render one resource each when their JSON is set
# -------------------------------------------------------------------------

run "singletons_managed_when_set" {
  command = plan

  # --- encoding json set -> one resource ---
  assert {
    condition     = length(jellyfin_encoding_configuration.this) == 1
    error_message = "encoding_configuration_json set -> one resource"
  }

  # --- live tv json set -> one resource ---
  assert {
    condition     = length(jellyfin_livetv_configuration.this) == 1
    error_message = "livetv_configuration_json set -> one resource"
  }

  # --- configuration_json passes through verbatim ---
  assert {
    condition     = jellyfin_encoding_configuration.this[0].configuration_json == var.encoding_configuration_json
    error_message = "configuration_json should pass through the encoding input verbatim"
  }
}

# -------------------------------------------------------------------------
# scheduled_tasks for_each: one resource per task, triggers_json verbatim
# -------------------------------------------------------------------------

run "scheduled_tasks_for_each" {
  command = plan

  # --- two task inputs -> two resources ---
  assert {
    condition     = length(jellyfin_scheduled_task.this) == 2
    error_message = "two scheduled_tasks -> two resources"
  }

  # --- task_id propagates from the map value ---
  assert {
    condition     = jellyfin_scheduled_task.this["guide-refresh"].task_id == "a558367c153e8b2ca2b0f9d4f5f8e6c1"
    error_message = "task_id should propagate from the map value"
  }

  # --- triggers_json passes through verbatim (no number coercion) ---
  assert {
    condition     = jellyfin_scheduled_task.this["guide-refresh"].triggers_json == var.scheduled_tasks["guide-refresh"].triggers_json
    error_message = "triggers_json should pass through the trigger list verbatim"
  }
}

# -------------------------------------------------------------------------
# Unset singletons are not managed
# -------------------------------------------------------------------------

run "singletons_skipped_when_null" {
  command = plan

  variables {
    encoding_configuration_json = null
    livetv_configuration_json   = null
    system_configuration_json   = null
  }

  # --- null encoding -> zero resources ---
  assert {
    condition     = length(jellyfin_encoding_configuration.this) == 0
    error_message = "null encoding_configuration_json -> zero resources"
  }

  # --- null livetv -> zero resources ---
  assert {
    condition     = length(jellyfin_livetv_configuration.this) == 0
    error_message = "null livetv_configuration_json -> zero resources"
  }
}

# -------------------------------------------------------------------------
# Empty inputs edge case: nothing managed
# -------------------------------------------------------------------------

run "empty_inputs" {
  command = plan

  variables {
    encoding_configuration_json = null
    livetv_configuration_json   = null
    system_configuration_json   = null
    scheduled_tasks             = {}
  }

  # --- no tasks -> zero scheduled task resources ---
  assert {
    condition     = length(jellyfin_scheduled_task.this) == 0
    error_message = "empty scheduled_tasks -> zero resources"
  }
}
