include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "object_storage" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/object-storage.hcl"
}
