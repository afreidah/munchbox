# -----------------------------------------------------------------------------
# OBJECT-STORAGE-IBM MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------
#
# ibmcloud_api_key wired explicitly: the env-var fallback isn't honored by
# every sub-service client in the provider (resource-manager in particular
# skips it and errors with "BearerToken property is required" at read time).
# IC_API_KEY itself is populated by munchbox-env.sh from vault:secret/ibm-cloud.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}
