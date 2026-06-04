# -----------------------------------------------------------------------------
# PROMETHEUS-ALERTS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "prometheus-alerts" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/prometheus-alerts.hcl"
  expose = true
}
