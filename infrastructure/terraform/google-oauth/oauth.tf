# -------------------------------------------------------------------------------
# Google OAuth Resources
#
# Project: Munchbox / Author: Alex Freidah
#
# Creates OAuth consent screen (IAP brand) and OAuth 2.0 client credentials.
# The brand resource is immutable after creation and must be imported if it
# already exists in the project.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# OAUTH CONSENT SCREEN
# -------------------------------------------------------------------------

resource "google_iap_brand" "authentik" {
  support_email     = var.support_email
  application_title = "Munchbox Auth"
  project           = "nextcloud-munchbox"

  depends_on = [google_project_service.iap]
}

# -------------------------------------------------------------------------
# OAUTH CLIENT CREDENTIALS
# -------------------------------------------------------------------------

resource "google_iap_client" "authentik" {
  display_name = "Authentik"
  brand        = google_iap_brand.authentik.name
}

# -------------------------------------------------------------------------
# STORE CREDENTIALS IN VAULT
# -------------------------------------------------------------------------

resource "vault_kv_secret_v2" "authentik_google_oauth" {
  mount = "secret"
  name  = "authentik/google-oauth"

  data_json = jsonencode({
    client_id     = google_iap_client.authentik.client_id
    client_secret = google_iap_client.authentik.secret
    redirect_uri  = "https://auth.munchbox.cc/source/oauth/callback/google/"
  })
}
