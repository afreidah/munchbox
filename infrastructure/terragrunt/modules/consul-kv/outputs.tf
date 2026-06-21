# -----------------------------------------------------------------------------
# CONSUL-KV Module Outputs
# -----------------------------------------------------------------------------

output "paths" {
  description = "Consul KV paths managed by this module."
  value       = keys(var.keys)
}
