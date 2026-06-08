# -----------------------------------------------------------------------------
# Postgres Database Module Outputs
# -----------------------------------------------------------------------------

output "role" {
  description = "Postgres login role name"
  value       = postgresql_role.app.name
  sensitive   = true
}

output "databases" {
  description = "Databases owned by the role"
  value       = [for d in postgresql_database.db : d.name]
}
