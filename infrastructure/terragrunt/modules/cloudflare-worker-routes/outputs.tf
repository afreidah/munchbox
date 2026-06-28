# -----------------------------------------------------------------------------
# CLOUDFLARE-WORKER-ROUTES MODULE - OUTPUTS
# -----------------------------------------------------------------------------

output "script_name" {
  description = "Name of the deployed Worker script."
  value       = cloudflare_workers_script.this.script_name
}

output "route_patterns" {
  description = "Route patterns bound to the script."
  value       = keys(cloudflare_workers_route.this)
}
