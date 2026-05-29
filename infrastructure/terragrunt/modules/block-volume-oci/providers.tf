# -----------------------------------------------------------------------------
# BLOCK-VOLUME-OCI MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------
#
# OCI provider reads ~/.oci/config (or OCI_* env vars). No wiring needed
# here; block exists so the provider's source resolves to oracle/oci.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

provider "oci" {}
