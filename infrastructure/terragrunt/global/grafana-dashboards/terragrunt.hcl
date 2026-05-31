# -----------------------------------------------------------------------------
# GRAFANA-DASHBOARDS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "grafana-dashboards" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/grafana-dashboards.hcl"
  expose = true
}
