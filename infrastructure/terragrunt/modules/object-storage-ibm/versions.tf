# -------------------------------------------------------------------------------
# OBJECT-STORAGE-IBM Module Version Requirements
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 2.0"
    }
  }
}
