# -------------------------------------------------------------------------------
# NETWORK Module Version Requirements
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    # aws is pulled in transitively by the networking/security-group submodules;
    # declare it here so consumers and `mock_provider "aws"` in tests resolve it.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}
