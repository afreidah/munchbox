# -----------------------------------------------------------------------------
# CLOUDFLARE-WORKER-ROUTES Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    # Reads a script built elsewhere out of an S3-compatible store. There is no
    # native provider for the orchestrator that serves it, so the S3 client is
    # the only way in.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
