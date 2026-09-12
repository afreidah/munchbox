# -----------------------------------------------------------------------------
# CLOUDFLARE-WORKER-ROUTES MODULE - OUTPUTS
# -----------------------------------------------------------------------------

output "script_names" {
  description = "Names of the deployed Worker scripts."
  value       = keys(cloudflare_workers_script.this)
}

output "route_patterns" {
  description = "Route patterns bound to the scripts."
  value       = [for r in values(cloudflare_workers_route.this) : r.pattern]
}
