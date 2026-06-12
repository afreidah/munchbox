# -----------------------------------------------------------------------------
# JELLYFIN-CONFIG Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    jellyfin = {
      source  = "ThePhaseless/jellyfin"
      version = "~> 0.1"
    }
  }
}
