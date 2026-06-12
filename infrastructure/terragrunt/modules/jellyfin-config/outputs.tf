# -----------------------------------------------------------------------------
# JELLYFIN-CONFIG Module Outputs
# -----------------------------------------------------------------------------

output "managed_singletons" {
  description = "Which singleton configs this module manages (true when a non-null input was supplied)."
  value = {
    encoding = length(jellyfin_encoding_configuration.this) > 0
    livetv   = length(jellyfin_livetv_configuration.this) > 0
    system   = length(jellyfin_system_configuration.this) > 0
  }
}

output "scheduled_task_ids" {
  description = "Map of Terraform key -> managed Jellyfin scheduled task id."
  value       = { for k, t in jellyfin_scheduled_task.this : k => t.task_id }
}
