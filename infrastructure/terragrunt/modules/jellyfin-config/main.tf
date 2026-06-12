# -----------------------------------------------------------------------------
# JELLYFIN-CONFIG MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages a self-hosted Jellyfin server's configuration: the singleton encoding,
# Live TV, and system config blobs, plus scheduled-task triggers. Each input is
# the provider's *_json string verbatim; the env_helper does the HCL-to-JSON
# encoding, so the concrete jellyfin keys stay in root.hcl and this module stays
# generic.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ENCODING CONFIGURATION (singleton)
# -----------------------------------------------------------------------------

resource "jellyfin_encoding_configuration" "this" {
  count = var.encoding_configuration_json == null ? 0 : 1

  configuration_json = var.encoding_configuration_json
}

# -----------------------------------------------------------------------------
# LIVE TV CONFIGURATION (singleton)
# -----------------------------------------------------------------------------

resource "jellyfin_livetv_configuration" "this" {
  count = var.livetv_configuration_json == null ? 0 : 1

  configuration_json = var.livetv_configuration_json
}

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION (singleton)
# -----------------------------------------------------------------------------

resource "jellyfin_system_configuration" "this" {
  count = var.system_configuration_json == null ? 0 : 1

  configuration_json = var.system_configuration_json
}

# -----------------------------------------------------------------------------
# SCHEDULED TASKS
# -----------------------------------------------------------------------------

resource "jellyfin_scheduled_task" "this" {
  for_each = var.scheduled_tasks

  task_id       = each.value.task_id
  triggers_json = each.value.triggers_json
}
