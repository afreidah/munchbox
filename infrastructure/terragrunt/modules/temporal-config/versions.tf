# -----------------------------------------------------------------------------
# TEMPORAL-CONFIG Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    temporal = {
      source  = "platacard/temporal"
      version = "~> 0.19"
    }
  }
}
