# -----------------------------------------------------------------------------
# LOKI-ALERTS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "loki_alerts" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/loki-alerts.hcl"
  expose = true
}
