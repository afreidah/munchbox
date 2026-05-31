# -----------------------------------------------------------------------------
# PROMETHEUS-ALERTS ENV HELPER
# -----------------------------------------------------------------------------
#
# Discovers `groups/*.yml` next to this helper and turns each into a Consul
# KV entry under `prometheus/alerts/<group>`. Edit a YAML, `terragrunt
# apply`, prom's consul-template re-renders alert_rules.yml and SIGHUPs.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//prometheus-alerts"
}

locals {
  groups_dir = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/prometheus-alerts/groups"
  group_files = fileset(local.groups_dir, "*.yml")
}

inputs = {
  groups = {
    for f in local.group_files :
    "prometheus/alerts/${trimsuffix(f, ".yml")}" => file("${local.groups_dir}/${f}")
  }
}
