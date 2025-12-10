# -------------------------------------------------------------------------------
# Google OAuth Resources
#
# Project: Munchbox / Author: Alex Freidah
#
# Creates OAuth consent screen and OAuth 2.0 Web Application client credentials
# for Authentik SSO integration. Stores credentials in Vault.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# OAUTH CONSENT SCREEN (using IAP brand for consent screen config)
# -------------------------------------------------------------------------

resource "google_iap_brand" "authentik" {
  support_email     = var.support_email
  application_title = "Munchbox Auth"
  project           = "nextcloud-munchbox"

  depends_on = [google_project_service.iap]
}

# -------------------------------------------------------------------------
# OAUTH CLIENT CREDENTIALS (Web Application type)
# -------------------------------------------------------------------------

resource "google_iap_client" "authentik" {
  display_name = "Authentik"
  brand        = google_iap_brand.authentik.name
}

# -------------------------------------------------------------------------
# STORE CREDENTIALS IN VAULT
# -------------------------------------------------------------------------

# NOTE: The google_iap_client resource does NOT support custom redirect URIs.
# You must manually add the redirect URI in Google Cloud Console:
#   1. Go to APIs & Services → Credentials
#   2. Click on the OAuth 2.0 Client ID "Authentik"
#   3. Under "Authorized redirect URIs", add:
#      https://auth.munchbox.cc/source/oauth/callback/google/
#
# Alternatively, create a separate Web Application OAuth client in the console
# and update the client_id/client_secret in Vault manually.

resource "vault_kv_secret_v2" "authentik_google_oauth" {
  mount = "secret"
  name  = "authentik/google-oauth"

  data_json = jsonencode({
    client_id     = google_iap_client.authentik.client_id
    client_secret = google_iap_client.authentik.secret
    redirect_uri  = "https://auth.munchbox.cc/source/oauth/callback/google/"
  })
}
