# -----------------------------------------------------------------------------
# TEMPORAL ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the temporal-config module. root.hcl holds the frontend
# connection and the schedule definitions; this helper json-encodes each
# schedule's input object into the workflow argument payload the provider
# expects (null input passes through untouched).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//temporal-config"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  temporal_host     = local.root.locals.temporal_host
  temporal_port     = local.root.locals.temporal_port
  temporal_insecure = local.root.locals.temporal_insecure

  schedules = {
    for k, s in local.root.locals.temporal_schedules :
    k => merge(s, { input = s.input == null ? null : jsonencode(s.input) })
  }
}
