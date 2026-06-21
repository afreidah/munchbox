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

# -----------------------------------------------------------------------------
# AUTO-UNSEAL IAM PRINCIPAL
# -----------------------------------------------------------------------------

# --- RSA keypair backing the unseal user's API key; private half feeds the cinc data bag ---
resource "tls_private_key" "unseal" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# IAM users and groups live in the tenancy root, not a sub-compartment.
resource "oci_identity_user" "unseal" {
  compartment_id = var.tenancy_ocid
  name           = var.unseal_user_name
  description    = "HashiCorp Vault auto-unseal; API-key principal scoped to key-use only"
  email          = var.unseal_user_email
  freeform_tags  = var.tags
}

resource "oci_identity_group" "unseal" {
  compartment_id = var.tenancy_ocid
  name           = var.unseal_group_name
  description    = "Grants use of the Vault auto-unseal key"
  freeform_tags  = var.tags
}

resource "oci_identity_user_group_membership" "unseal" {
  user_id  = oci_identity_user.unseal.id
  group_id = oci_identity_group.unseal.id
}

resource "oci_identity_api_key" "unseal" {
  user_id   = oci_identity_user.unseal.id
  key_value = tls_private_key.unseal.public_key_pem
}

# --- least privilege: crypto use of the one unseal key, nothing else ---
resource "oci_identity_policy" "unseal" {
  compartment_id = var.compartment_id
  name           = var.unseal_policy_name
  description    = "Vault auto-unseal: use the KMS unseal key only"

  statements = [
    "Allow group ${oci_identity_group.unseal.name} to use keys in compartment id ${var.compartment_id} where target.key.id = '${oci_kms_key.this.id}'"
  ]

  freeform_tags = var.tags
}
