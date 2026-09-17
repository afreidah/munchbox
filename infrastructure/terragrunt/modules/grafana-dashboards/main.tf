# -----------------------------------------------------------------------------
# GRAFANA-DASHBOARDS MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Provisions Grafana dashboards via the grafana provider. Each *.json under
# var.dashboards_dir becomes a grafana_dashboard resource keyed by filename
# slug. Bodies are read with file() so the ~MB-size JSON content doesn't go
# through the TF_VAR env-var path (blew ARG_MAX on first init).
#
# A dashboard whose source of truth lives in the repository that emits it is
# named in var.remote_dashboards instead and fetched from the artifact store,
# so no copy of it is kept here.
#
# Folder is assumed to exist (created out-of-band; see folder_uid default).
# -----------------------------------------------------------------------------

locals {
  # --- enumerate dashboard JSONs; slug = filename without .json ---
  dashboard_files = fileset(var.dashboards_dir, "*.json")
  local_dashboards = {
    for f in local.dashboard_files :
    trimsuffix(f, ".json") => file("${var.dashboards_dir}/${f}")
  }

  remote_dashboards = {
    for slug in keys(var.remote_dashboards) :
    slug => data.aws_s3_object.dashboard[slug].body
  }

  dashboards = merge(local.local_dashboards, local.remote_dashboards)
}

# -------------------------------------------------------------------------
# REMOTE BODIES - published by the repository that owns the dashboard
# -------------------------------------------------------------------------

data "aws_s3_object" "dashboard" {
  for_each = var.remote_dashboards

  bucket = each.value.bucket
  key    = each.value.key
}

# -------------------------------------------------------------------------
# DASHBOARDS - one per JSON body, all pinned to the same folder
# -------------------------------------------------------------------------

resource "grafana_dashboard" "managed" {
  for_each = local.dashboards

  folder      = var.folder_uid
  config_json = each.value

  # --- overwrite existing dashboards with same uid; required for repeat applies ---
  overwrite = true
}
