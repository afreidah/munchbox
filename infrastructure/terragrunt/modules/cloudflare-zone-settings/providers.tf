# -----------------------------------------------------------------------------
# CLOUDFLARE-ZONE-SETTINGS MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
