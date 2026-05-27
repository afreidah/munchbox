# -------------------------------------------------------------------------------
# NOMAD-CONFIG Module Version Requirements
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 2.0"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "~> 0.12"
    }
    forgejo = {
      source  = "svalabs/forgejo"
      version = "~> 1.1"
    }
    pihole = {
      source  = "ryanwholey/pihole"
      version = "~> 0.2"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1"
    }
  }
}
