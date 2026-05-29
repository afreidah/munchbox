# -----------------------------------------------------------------------------
# REMOTE-FILES Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
