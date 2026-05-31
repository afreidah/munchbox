# -----------------------------------------------------------------------------
# GRAFANA-DASHBOARDS MODULE - Provider Config
# -----------------------------------------------------------------------------

provider "grafana" {
  url  = var.grafana_url
  auth = "${var.grafana_admin_user}:${var.grafana_admin_password}"
}
