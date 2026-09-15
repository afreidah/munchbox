# -----------------------------------------------------------------------------
# jellyfin-config module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the singleton count-gating (a config renders one resource when its
# object is set, zero when null), attribute pass-through, the scheduled_tasks
# for_each fan-out, and the all-empty edge case.
# -----------------------------------------------------------------------------

mock_provider "jellyfin" {}

variables {
  jellyfin_endpoint = "http://mock-jellyfin.test:8096"
  jellyfin_api_key  = "mock-api-key"

  encoding_configuration = {
    enable_hardware_encoding = true
    h264_crf                 = 23
  }

  livetv_configuration = {
    pre_padding_seconds = 120
    tuner_hosts         = []
    listing_providers   = []
  }

  scheduled_tasks = {
    "guide-refresh" = {
      task_id  = "a558367c153e8b2ca2b0f9d4f5f8e6c1"
      triggers = [{ type = "IntervalTrigger", interval_ticks = 432000000000 }]
    }
    "scan-library" = {
      task_id  = "7738148ffcd07979c7ceb148e06b3aed"
      triggers = [{ type = "DailyTrigger", time_of_day_ticks = 0 }]
    }
  }
}

# -------------------------------------------------------------------------
# Singleton configs render one resource each when their object is set
# -------------------------------------------------------------------------

run "singletons_managed_when_set" {
  command = plan

  # --- encoding object set -> one resource ---
  assert {
    condition     = length(jellyfin_encoding_configuration.this) == 1
    error_message = "encoding_configuration set -> one resource"
  }

  # --- live tv object set -> one resource ---
  assert {
    condition     = length(jellyfin_livetv_configuration.this) == 1
    error_message = "livetv_configuration set -> one resource"
  }

  # --- set attributes pass through to the resource ---
  assert {
    condition     = jellyfin_encoding_configuration.this[0].h264_crf == 23
    error_message = "h264_crf should pass through the encoding input"
  }

  # --- managed_singletons reflects which configs are set ---
  assert {
    condition     = output.managed_singletons.encoding == true && output.managed_singletons.livetv == true && output.managed_singletons.system == false
    error_message = "managed_singletons must be true for set configs and false for unset system"
  }
}

# -------------------------------------------------------------------------
# scheduled_tasks for_each: one resource per task, triggers verbatim
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

  # --- trigger ticks survive as numbers, without coercion ---
  assert {
    condition     = jellyfin_scheduled_task.this["guide-refresh"].triggers[0].interval_ticks == 432000000000
    error_message = "interval_ticks should pass through the trigger list verbatim"
  }

  # --- trigger type propagates ---
  assert {
    condition     = jellyfin_scheduled_task.this["scan-library"].triggers[0].type == "DailyTrigger"
    error_message = "trigger type should propagate from the map value"
  }

  # --- scheduled_task_ids keys on every task and carries its task_id ---
  assert {
    condition     = toset(keys(output.scheduled_task_ids)) == toset(["guide-refresh", "scan-library"])
    error_message = "scheduled_task_ids must key on every scheduled task"
  }

  # --- scheduled_task_ids value is the input task_id ---
  assert {
    condition     = output.scheduled_task_ids["guide-refresh"] == "a558367c153e8b2ca2b0f9d4f5f8e6c1"
    error_message = "scheduled_task_ids value must be the input task_id"
  }
}

# -------------------------------------------------------------------------
# Unset singletons are not managed
# -------------------------------------------------------------------------

run "singletons_skipped_when_null" {
  command = plan

  variables {
    encoding_configuration = null
    livetv_configuration   = null
    system_configuration   = null
  }

  # --- null encoding -> zero resources ---
  assert {
    condition     = length(jellyfin_encoding_configuration.this) == 0
    error_message = "null encoding_configuration -> zero resources"
  }

  # --- null livetv -> zero resources ---
  assert {
    condition     = length(jellyfin_livetv_configuration.this) == 0
    error_message = "null livetv_configuration -> zero resources"
  }
}

# -------------------------------------------------------------------------
# system_configuration set -> system singleton is managed
# -------------------------------------------------------------------------

run "system_singleton_managed" {
  command = plan

  variables {
    system_configuration = {
      server_name    = "munchbox"
      enable_metrics = true
    }
  }

  # --- system object set -> one resource ---
  assert {
    condition     = length(jellyfin_system_configuration.this) == 1
    error_message = "system_configuration set -> one resource"
  }

  # --- managed_singletons.system flips true when system config is set ---
  assert {
    condition     = output.managed_singletons.system == true
    error_message = "managed_singletons.system must be true when system config is set"
  }
}

# -------------------------------------------------------------------------
# Empty inputs edge case: nothing managed
# -------------------------------------------------------------------------

run "empty_inputs" {
  command = plan

  variables {
    encoding_configuration = null
    livetv_configuration   = null
    system_configuration   = null
    scheduled_tasks        = {}
  }

  # --- no tasks -> zero scheduled task resources ---
  assert {
    condition     = length(jellyfin_scheduled_task.this) == 0
    error_message = "empty scheduled_tasks -> zero resources"
  }
}
