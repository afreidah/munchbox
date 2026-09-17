# -----------------------------------------------------------------------------
# GRAFANA-DASHBOARDS Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.0"
    }
    # Reads dashboards built elsewhere out of an S3-compatible store. There is
    # no native provider for the orchestrator that serves it, so the S3 client
    # is the only way in.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
