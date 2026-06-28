# -----------------------------------------------------------------------------
# CLOUDFLARE-WAF MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------
#
# Auth comes from the scoped "wafbot" token (Zone WAF + Bot Management +
# Firewall for AI), supplied by the cloudflare-tokens dependency.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
