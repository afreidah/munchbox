# -----------------------------------------------------------------------------
# PIHOLE-CONFIG Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    pihole = {
      source  = "dklesev/pihole"
      version = "~> 1.0"
    }
  }
}
