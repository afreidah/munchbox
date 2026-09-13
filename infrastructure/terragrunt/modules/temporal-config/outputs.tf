# -----------------------------------------------------------------------------
# TEMPORAL-CONFIG Module Outputs
# -----------------------------------------------------------------------------

output "namespaces" {
  description = "Map of managed Temporal namespace name -> retention in days."
  value       = { for k, n in temporal_namespace.this : k => n.retention }
}

output "schedules" {
  description = "Map of Terraform key -> managed Temporal schedule (id + namespace)."
  value = {
    for k, s in temporal_schedule.this : k => {
      schedule_id = s.schedule_id
      namespace   = s.namespace
    }
  }
}
