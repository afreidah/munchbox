# -----------------------------------------------------------------------------
# CLOUDFLARE-WAF Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.7" # import blocks with for_each

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}
