# -----------------------------------------------------------------------------
# FORGEJO-SECRETS MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------
#
# Forgejo provider auth is supplied by the env_helper as inputs. host falls
# back to the in-cluster consul-DNS name when FORGEJO_HOST isn't exported.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

provider "forgejo" {
  host      = var.forgejo_host
  api_token = var.forgejo_api_token
}
