# -----------------------------------------------------------------------------
# CLOUDFLARE-WORKER-ROUTES MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------
#
# Auth comes from a token with Workers Scripts + Routes write, supplied by the
# caller (e.g. the cloudflare-tokens dependency).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
