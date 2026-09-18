# -----------------------------------------------------------------------------
# GRAFANA-DASHBOARDS MODULE - Provider Config
# -----------------------------------------------------------------------------

provider "grafana" {
  url  = var.grafana_url
  auth = "${var.grafana_admin_user}:${var.grafana_admin_password}"
}

# --- Serves the dashboards fetched from the artifact store. The endpoint is
#     S3-compatible rather than AWS, so path-style addressing is forced and the
#     AWS-only preflight calls are skipped. ---
provider "aws" {
  # checkov:skip=CKV_AWS_41: the key is a dependency output, reported as a literal only because checkov renders TF_VAR_artifact_store from the environment
  access_key = var.artifact_store.access_key
  secret_key = var.artifact_store.secret_key
  region     = var.artifact_store.region

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = var.artifact_store.endpoint
  }
}
