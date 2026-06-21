include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "postgres_database" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/postgres-database.hcl"
}
