# -----------------------------------------------------------------------------
# KMS MODULE - OUTPUT VALUES - ORACLE CLOUD
# -----------------------------------------------------------------------------
#
# This file exposes attributes of the created KMS vault and encryption key
# for use by parent modules and HashiCorp Vault configuration.
#
# Output Categories:
#   - Vault Identifiers: OCI KMS vault OCID and display name
#   - Key Identifiers: Master encryption key OCID and display name
#   - Endpoints: Crypto and management API endpoints
#   - Seal Configuration: Pre-formatted values for Vault seal stanza
#
# Usage:
#   - key_id: Required for HashiCorp Vault ocikms seal stanza
#   - crypto_endpoint: Required for encryption/decryption operations
#   - management_endpoint: Required for key management operations
#   - vault_seal_config: Convenience output with all seal stanza values
#
# HashiCorp Vault Seal Stanza Example:
#   seal "ocikms" {
#     key_id              = "<key_id output>"
#     crypto_endpoint     = "<crypto_endpoint output>"
#     management_endpoint = "<management_endpoint output>"
#     auth_type_api_key   = true  # or use instance principal
#   }
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VAULT IDENTIFIERS
# -----------------------------------------------------------------------------

output "vault_id" {
  description = "OCID of the OCI KMS vault (logical key container)"
  value       = oci_kms_vault.this.id
}

output "vault_display_name" {
  description = "Display name of the OCI KMS vault"
  value       = oci_kms_vault.this.display_name
}

output "vault_state" {
  description = "Current lifecycle state of the OCI KMS vault (ACTIVE, DELETED, etc.)"
  value       = oci_kms_vault.this.state
}

# -----------------------------------------------------------------------------
# KEY IDENTIFIERS
# -----------------------------------------------------------------------------

output "key_id" {
  description = "OCID of the master encryption key (required for Vault seal stanza)"
  value       = oci_kms_key.this.id
}

output "key_display_name" {
  description = "Display name of the master encryption key"
  value       = oci_kms_key.this.display_name
}

output "key_state" {
  description = "Current lifecycle state of the encryption key (ENABLED, DISABLED, etc.)"
  value       = oci_kms_key.this.state
}

output "protection_mode" {
  description = "Key protection mode (SOFTWARE or HSM)"
  value       = oci_kms_key.this.protection_mode
}

# -----------------------------------------------------------------------------
# ENDPOINTS
# -----------------------------------------------------------------------------

output "crypto_endpoint" {
  description = "Cryptographic operations endpoint for encrypt/decrypt API calls"
  value       = oci_kms_vault.this.crypto_endpoint
}

output "management_endpoint" {
  description = "Management operations endpoint for key lifecycle API calls"
  value       = oci_kms_vault.this.management_endpoint
}

# -----------------------------------------------------------------------------
# SEAL CONFIGURATION
# -----------------------------------------------------------------------------

output "vault_seal_config" {
  description = "Pre-formatted configuration values for HashiCorp Vault ocikms seal stanza"
  value = {
    key_id              = oci_kms_key.this.id
    crypto_endpoint     = oci_kms_vault.this.crypto_endpoint
    management_endpoint = oci_kms_vault.this.management_endpoint
  }
}
