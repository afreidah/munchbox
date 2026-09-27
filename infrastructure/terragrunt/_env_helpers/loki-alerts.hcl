# -----------------------------------------------------------------------------
# LOKI-ALERTS ENV HELPER
# -----------------------------------------------------------------------------
#
# Discovers `groups/*.yml` next to this helper and turns each into a Consul
# KV entry under `loki/alerts/<group>`. Edit a YAML, `terragrunt apply`,
# loki's consul-template re-renders the rule file and the ruler picks it up
# on its next poll.
#
# Shares the alert-rules module with prometheus-alerts; the prefix in the key
# is what decides which job reads a group.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//alert-rules"
}

locals {
  groups_dir  = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/loki-alerts/groups"
  group_files = fileset(local.groups_dir, "*.yml")
}

inputs = {
  groups = {
    for f in local.group_files :
    "loki/alerts/${trimsuffix(f, ".yml")}" => file("${local.groups_dir}/${f}")
  }
}
