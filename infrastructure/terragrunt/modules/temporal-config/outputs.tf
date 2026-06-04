# -----------------------------------------------------------------------------
# TEMPORAL-CONFIG Module Outputs
# -----------------------------------------------------------------------------

output "schedules" {
  description = "Map of Terraform key -> managed Temporal schedule (id + namespace)."
  value = {
    for k, s in temporal_schedule.this : k => {
      schedule_id = s.schedule_id
      namespace   = s.namespace
    }
  }
}
