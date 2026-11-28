# -----------------------------------------------------------------------------
# RAMBLE Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    ramble = {
      source  = "open-wander/ramble"
      version = "~> 0.1"
    }
  }
}
