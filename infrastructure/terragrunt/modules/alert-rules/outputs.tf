# -----------------------------------------------------------------------------
# PROMETHEUS-ALERTS Module Outputs
# -----------------------------------------------------------------------------

output "group_count" {
  description = "Number of alert-group KV entries managed."
  value       = length(var.groups)
}

output "group_paths" {
  description = "Sorted list of Consul KV paths managed by this leaf."
  value       = sort(keys(var.groups))
}
