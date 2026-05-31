# -----------------------------------------------------------------------------
# GRAFANA-DASHBOARDS ENV HELPER
# -----------------------------------------------------------------------------
#
# Points the module at the on-disk dashboards/ dir; the module discovers
# *.json there and pushes each to grafana via the API. Edit a JSON,
# terragrunt apply, no nomad redeploy and no consul-template delimiter
# escape ceremony.
#
# Bodies are loaded lazily by the module (file()) instead of passed inline
# through inputs -- the inline form blows ARG_MAX once the JSON corpus
# crosses ~1MB (node-exporter-full alone is 470KB).
#
# Auth + URL: grafana provider talks to the internal grafana endpoint
# (http://grafana.service.consul:3030) to bypass oauth2-proxy. Credentials
# come from TF_VAR_grafana_admin_{user,password} exported by munchbox-env.sh.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//grafana-dashboards"
}

inputs = {
  grafana_url            = "http://grafana.service.consul:3030"
  grafana_admin_user     = get_env("TF_VAR_grafana_admin_user", "")
  grafana_admin_password = get_env("TF_VAR_grafana_admin_password", "")
  dashboards_dir         = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/grafana-dashboards/dashboards"
}
