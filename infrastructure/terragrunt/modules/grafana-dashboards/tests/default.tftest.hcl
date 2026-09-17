# -----------------------------------------------------------------------------
# grafana-dashboards module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# The module enumerates *.json under var.dashboards_dir (via fileset) and
# creates one grafana_dashboard per file, slug = filename without .json. These
# tests point dashboards_dir at tests/fixtures (two JSONs) and assert the
# for_each fan-out, folder_uid propagation, the dashboard_count + dashboard_slugs
# outputs, the empty-dir edge case (tests/fixtures-empty), and that a
# remote_dashboards entry joins the same fan-out.
# -----------------------------------------------------------------------------

mock_provider "grafana" {}
# --- A generated body would be random text, and the grafana provider parses
#     config_json at plan time. ---
mock_provider "aws" {
  mock_data "aws_s3_object" {
    defaults = {
      body = "{\"title\":\"mock\"}"
    }
  }
}

variables {
  grafana_url            = "http://mock.test:3030"
  grafana_admin_user     = "admin"
  grafana_admin_password = "mock-pw"
  dashboards_dir         = "./tests/fixtures"

  artifact_store = {
    endpoint   = "http://mock.test:9000"
    access_key = "MOCKACCESSKEY"
    secret_key = "mock-secret-key"
  }
}

# -------------------------------------------------------------------------
# Dashboards for_each: one resource per JSON file in dashboards_dir
# -------------------------------------------------------------------------

run "dashboards_for_each" {
  command = plan

  # --- two JSON files -> two resources ---
  assert {
    condition     = length(grafana_dashboard.managed) == 2
    error_message = "two dashboard JSON files -> two grafana_dashboard resources"
  }

  # --- slug keys derive from filename without .json ---
  assert {
    condition     = toset(keys(grafana_dashboard.managed)) == toset(["infrastructure-services", "nomad-cluster-overview"])
    error_message = "dashboard keys must be filename slugs"
  }

  # --- folder_uid default flows through ---
  assert {
    condition     = grafana_dashboard.managed["infrastructure-services"].folder == "munchbox-folder"
    error_message = "default folder_uid must propagate to grafana_dashboard.folder"
  }

  # --- dashboard_count output counts discovered dashboards ---
  assert {
    condition     = output.dashboard_count == 2
    error_message = "dashboard_count output must equal the number of discovered dashboards"
  }

  # --- dashboard_slugs output lists every discovered slug ---
  assert {
    condition     = toset(output.dashboard_slugs) == toset(["infrastructure-services", "nomad-cluster-overview"])
    error_message = "dashboard_slugs output must list every discovered slug"
  }
}

# -------------------------------------------------------------------------
# Remote dashboards: fetched bodies join the same fan-out as the on-disk ones
# -------------------------------------------------------------------------

run "remote_dashboards" {
  command = plan

  variables {
    remote_dashboards = {
      "s3-orchestrator" = {
        bucket = "artifacts"
        key    = "s3-orchestrator/grafana/v1.2.3/s3-orchestrator.json"
      }
    }
  }

  # --- the object is fetched at the key the caller pinned ---
  assert {
    condition     = data.aws_s3_object.dashboard["s3-orchestrator"].key == "s3-orchestrator/grafana/v1.2.3/s3-orchestrator.json"
    error_message = "remote dashboard must be fetched at the pinned key"
  }

  # --- two on-disk + one remote -> three resources ---
  assert {
    condition     = toset(keys(grafana_dashboard.managed)) == toset(["infrastructure-services", "nomad-cluster-overview", "s3-orchestrator"])
    error_message = "remote dashboards must merge into the on-disk set"
  }

  # --- outputs count remote dashboards too ---
  assert {
    condition     = output.dashboard_count == 3
    error_message = "dashboard_count output must include remote dashboards"
  }
}

# -------------------------------------------------------------------------
# Empty dir: no JSON files -> no resources, zero-valued outputs
# -------------------------------------------------------------------------

run "empty_dashboards" {
  command = plan

  variables {
    dashboards_dir = "./tests/fixtures-empty"
  }

  # --- empty dir -> no resources ---
  assert {
    condition     = length(grafana_dashboard.managed) == 0
    error_message = "empty dashboards dir -> zero grafana_dashboard resources"
  }

  # --- dashboard_count output is zero for an empty dir ---
  assert {
    condition     = output.dashboard_count == 0
    error_message = "dashboard_count output must be zero for an empty dir"
  }

  # --- dashboard_slugs output is empty for an empty dir ---
  assert {
    condition     = length(output.dashboard_slugs) == 0
    error_message = "dashboard_slugs output must be empty for an empty dir"
  }
}
