# -----------------------------------------------------------------------------
# KMS MODULE - ORACLE CLOUD
# -----------------------------------------------------------------------------
#
# This module creates an OCI Key Management Service (KMS) vault and master
# encryption key for HashiCorp Vault auto-unseal functionality. The OCI KMS
# service provides centralized key management with optional hardware security
# module (HSM) protection.
#
# Components Created:
#   - KMS Vault: Logical container for encryption keys with dedicated endpoints
#   - Master Encryption Key: AES-256 key used by HashiCorp Vault for auto-unseal
#
# Architecture:
#   - OCI KMS vaults provide dedicated crypto and management endpoints
#   - Keys cannot be exported; all crypto operations occur within OCI
#   - Software-protected keys are free; HSM keys have per-version costs
#   - HashiCorp Vault uses the key to encrypt/decrypt its master key
#
# Security Model:
#   - Key Material Isolation: Keys never leave OCI KMS boundary
#   - IAM Integration: Access controlled via OCI policies and instance principals
#   - Audit Logging: All key operations logged in OCI Audit service
#   - Protection Modes: SOFTWARE (free) or HSM (FIPS 140-2 Level 3)
#
# Auto-Unseal Flow:
#   - HashiCorp Vault encrypts its master key with the OCI KMS key
#   - On startup, Vault calls OCI KMS to decrypt the master key
#   - Eliminates need for manual unseal or Shamir key distribution
#   - Requires network access from Vault servers to OCI KMS endpoints
#
# IMPORTANT:
#   - Deleting the KMS key renders all Vault data permanently inaccessible
#   - OCI KMS vaults have a 30-day deletion pending period
#   - Vault servers need IAM permissions to use the key (instance principal or API key)
#   - Management and crypto endpoints are region-specific
#   - Consider key rotation policies for compliance requirements
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# KMS VAULT
# -----------------------------------------------------------------------------

# OCI KMS Vault provides a logical container for encryption keys
# Each vault has dedicated crypto and management endpoints
# DEFAULT type uses shared HSM infrastructure (free tier eligible)
resource "oci_kms_vault" "this" {
  compartment_id = var.compartment_id
  display_name   = var.vault_display_name
  vault_type     = var.vault_type

  freeform_tags = var.tags
}

# -----------------------------------------------------------------------------
# MASTER ENCRYPTION KEY
# -----------------------------------------------------------------------------

# AES-256 master encryption key for HashiCorp Vault auto-unseal
# Key material never leaves OCI KMS; all operations performed server-side
# SOFTWARE protection mode is free; HSM mode requires key version billing
resource "oci_kms_key" "this" {
  compartment_id      = var.compartment_id
  display_name        = var.key_display_name
  management_endpoint = oci_kms_vault.this.management_endpoint
  protection_mode     = var.protection_mode

  key_shape {
    algorithm = "AES"
    length    = 32 # 256-bit key for AES-256 encryption
  }

  freeform_tags = var.tags

  # Ensure vault is fully provisioned before creating key
  depends_on = [oci_kms_vault.this]
}
