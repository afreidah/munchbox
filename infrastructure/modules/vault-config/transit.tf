# -------------------------------------------------------------------------------
# TRANSIT SECRETS ENGINE
#
# Project: Munchbox / Author: Alex Freidah
#
# Provides encryption as a service and cryptographic key management. Used for
# container image signing with cosign.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# TRANSIT SECRETS ENGINE
# -------------------------------------------------------------------------

resource "vault_mount" "transit" {
  count       = var.transit_enabled ? 1 : 0
  path        = "transit"
  type        = "transit"
  description = "Transit secrets engine for encryption and signing"
}

# -------------------------------------------------------------------------
# SIGNING KEYS
# -------------------------------------------------------------------------

resource "vault_transit_secret_backend_key" "cosign" {
  count                  = var.transit_enabled ? 1 : 0
  backend                = vault_mount.transit[0].path
  name                   = "cosign"
  type                   = "ecdsa-p256"
  deletion_allowed       = false
  exportable             = false
  allow_plaintext_backup = false
}
