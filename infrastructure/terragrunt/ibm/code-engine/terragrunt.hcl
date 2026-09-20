# -----------------------------------------------------------------------------
# IBM CODE ENGINE LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "code_engine" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/code-engine.hcl"
  expose = true
}
