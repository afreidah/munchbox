# -------------------------------------------------------------------------------
# APTLY-SECRETS Module Version Requirements
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    htpasswd = {
      source  = "loafoe/htpasswd"
      version = "~> 2.1"
    }
  }
}
