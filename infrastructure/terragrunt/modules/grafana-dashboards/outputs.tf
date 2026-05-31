# -----------------------------------------------------------------------------
# GRAFANA-DASHBOARDS Module Outputs
# -----------------------------------------------------------------------------

output "dashboard_count" {
  description = "Number of dashboards discovered + managed by this leaf."
  value       = length(local.dashboards)
}

output "dashboard_slugs" {
  description = "Sorted list of dashboard slugs being provisioned."
  value       = sort(keys(local.dashboards))
}
