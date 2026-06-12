# -----------------------------------------------------------------------------
# JELLYFIN-CONFIG MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------

provider "jellyfin" {
  endpoint = var.jellyfin_endpoint
  api_key  = var.jellyfin_api_key
}
