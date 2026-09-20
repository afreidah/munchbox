# -----------------------------------------------------------------------------
# CODE-ENGINE MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------
#
# ibmcloud_api_key wired explicitly for the same reason object-storage-ibm does:
# the env-var fallback is not honored by every sub-service client, and
# resource-manager in particular errors with "BearerToken property is required"
# at read time. IC_API_KEY is populated by munchbox-env.sh from
# vault:secret/ibm-cloud.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}
