# -------------------------------------------------------------------------------
# BOOTSTRAP Module Version Requirements
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
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
