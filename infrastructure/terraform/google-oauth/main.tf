# -------------------------------------------------------------------------------
# Google OAuth Configuration for Authentik
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages Google Cloud OAuth credentials for Authentik SSO integration. Creates
# OAuth consent screen and client credentials, storing the client secret in
# Vault for retrieval by Authentik. Note that google_iap_brand can only be
# created once per project and cannot be deleted via API.
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.25"
    }
  }

  backend "consul" {
    address = "stabler:8500"
    scheme  = "http"
    path    = "terraform/google-oauth"
  }
}

# -------------------------------------------------------------------------
# PROVIDERS
# -------------------------------------------------------------------------

provider "google" {
  project = "nextcloud-munchbox"
  region  = "us-west1"
}

provider "vault" {
  address = "https://192.168.68.61:8200"
}

# -------------------------------------------------------------------------
# ENABLE REQUIRED APIS
# -------------------------------------------------------------------------

resource "google_project_service" "iap" {
  service            = "iap.googleapis.com"
  disable_on_destroy = false
}
