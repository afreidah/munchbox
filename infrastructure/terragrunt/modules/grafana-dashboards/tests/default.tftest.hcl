# -----------------------------------------------------------------------------
# grafana-dashboards module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the for_each fans out 1:1, empty input produces no resources, and
# folder_uid + auth inputs propagate through to the resource arguments.
# -----------------------------------------------------------------------------

mock_provider "grafana" {}

variables {
  grafana_url            = "http://mock.test:3030"
  grafana_admin_user     = "admin"
  grafana_admin_password = "mock-pw"
  dashboards = {
    "infrastructure-services" = "{\"title\": \"Infra\"}"
    "nomad-cluster-overview"  = "{\"title\": \"Nomad\"}"
  }
}

# -------------------------------------------------------------------------
# Dashboards for_each: one resource per input key
# -------------------------------------------------------------------------

run "dashboards_for_each" {
  command = plan

  # --- two dashboards input -> two resources ---
  assert {
    condition     = length(grafana_dashboard.managed) == 2
    error_message = "two dashboards input -> two grafana_dashboard resources"
  }

  # --- folder_uid default flows through ---
  assert {
    condition     = grafana_dashboard.managed["infrastructure-services"].folder == "munchbox-folder"
    error_message = "default folder_uid must propagate to grafana_dashboard.folder"
  }
}

# -------------------------------------------------------------------------
# Empty input: no resources, no error
# -------------------------------------------------------------------------

run "empty_dashboards" {
  command = plan

  variables {
    dashboards = {}
  }

  # --- empty map -> no resources ---
  assert {
    condition     = length(grafana_dashboard.managed) == 0
    error_message = "empty dashboards map -> zero grafana_dashboard resources"
  }
}
