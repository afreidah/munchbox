# -----------------------------------------------------------------------------
# S3-ORCHESTRATOR Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    # 0.189 is where a bucket's stored_form and replication_factor arrive; an
    # older provider installs cleanly and then fails on an unsupported argument.
    s3orchestrator = {
      source  = "afreidah/s3-orchestrator"
      version = "~> 0.189"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0"
    }
  }
}
