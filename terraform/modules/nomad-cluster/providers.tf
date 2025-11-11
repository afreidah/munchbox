# -----------------------------------------------------------------------------
# PROVIDERS
# -----------------------------------------------------------------------------
# Nomad provider configuration is expected to be supplied by the root module
# via environment variables (NOMAD_ADDR, NOMAD_TOKEN, etc.) or an explicit
# provider block. We declare the requirement and version constraint here.
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.0"
    }
  }
}
