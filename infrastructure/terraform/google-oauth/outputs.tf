# -------------------------------------------------------------------------------
# Google OAuth Configuration - Outputs
#
# Project: Munchbox / Author: Alex Freidah
#
# Exposes OAuth client ID and Vault path. Client secret is stored in Vault only.
# Redirect URI must be manually configured in Google Cloud Console.
# -------------------------------------------------------------------------------

output "oauth_client_id" {
  description = "Google OAuth client ID (safe to expose)"
  value       = google_iap_client.authentik.client_id
}

output "vault_secret_path" {
  description = "Vault path where credentials are stored"
  value       = "secret/data/authentik/google-oauth"
}

output "redirect_uri" {
  description = "OAuth redirect URI configured for Authentik"
  value       = "https://auth.munchbox.cc/source/oauth/callback/google/"
}

output "iap_brand_name" {
  description = "IAP brand resource name (for import if needed)"
  value       = google_iap_brand.authentik.name
}
