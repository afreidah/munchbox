# -----------------------------------------------------------------------------
# GRAFANA-DASHBOARDS MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Provisions Grafana dashboards via the grafana provider. Each *.json under
# var.dashboards_dir becomes a grafana_dashboard resource keyed by filename
# slug. Bodies are loaded lazily with file() so the ~MB-size JSON content
# doesn't go through the TF_VAR env-var path (blew ARG_MAX on first init).
# Folder is assumed to exist (created out-of-band; see folder_uid default).
# -----------------------------------------------------------------------------

locals {
  # --- enumerate dashboard JSONs; slug = filename without .json ---
  dashboard_files = fileset(var.dashboards_dir, "*.json")
  dashboards = {
    for f in local.dashboard_files :
    trimsuffix(f, ".json") => "${var.dashboards_dir}/${f}"
  }
}

# -------------------------------------------------------------------------
# DASHBOARDS - one per JSON file, all pinned to the same folder
# -------------------------------------------------------------------------

resource "grafana_dashboard" "managed" {
  for_each = local.dashboards

  folder      = var.folder_uid
  config_json = file(each.value)

  # --- overwrite existing dashboards with same uid; required for repeat applies ---
  overwrite = true
}
