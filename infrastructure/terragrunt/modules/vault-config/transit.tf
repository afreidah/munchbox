# -------------------------------------------------------------------------------
# TRANSIT SECRETS ENGINE
#
# Project: Munchbox / Author: Alex Freidah
#
# Provides encryption as a service and cryptographic key management. Used for
# container image signing with cosign and s3-orchestrator envelope encryption.
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

# -------------------------------------------------------------------------
# ENCRYPTION KEYS
# -------------------------------------------------------------------------

resource "vault_transit_secret_backend_key" "s3_orchestrator" {
  count                  = var.transit_enabled ? 1 : 0
  backend                = vault_mount.transit[0].path
  name                   = "s3-orchestrator"
  type                   = "aes256-gcm96"
  deletion_allowed       = false
  exportable             = false
  allow_plaintext_backup = false
}

# -------------------------------------------------------------------------
# S3-ORCHESTRATOR TRANSIT POLICY
# -------------------------------------------------------------------------
# Grants encrypt/decrypt on the s3-orchestrator key for envelope encryption.
# Attached to a dedicated JWT role so only the s3-orchestrator Nomad job
# receives these capabilities.

resource "vault_policy" "s3_orchestrator_transit" {
  count = var.transit_enabled ? 1 : 0
  name  = "s3-orchestrator-transit"

  policy = <<EOT
path "transit/encrypt/s3-orchestrator" {
  capabilities = ["create", "update"]
}

path "transit/decrypt/s3-orchestrator" {
  capabilities = ["create", "update"]
}

path "transit/keys/s3-orchestrator" {
  capabilities = ["read"]
}
EOT
}
