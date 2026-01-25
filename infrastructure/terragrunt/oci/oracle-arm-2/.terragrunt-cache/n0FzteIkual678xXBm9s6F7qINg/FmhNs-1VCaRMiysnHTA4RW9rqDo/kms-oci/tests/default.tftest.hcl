# -----------------------------------------------------------------------------
# KMS MODULE - TEST SUITE - ORACLE CLOUD
# -----------------------------------------------------------------------------
#
# This test suite validates the OCI KMS module logic, composite outputs, and
# edge cases. Tests focus on computed values and behavior, not variable
# pass-through validation.
#
# Test Categories:
#   - Key Shape: AES-256 configuration always applied correctly
#   - Seal Configuration: Composite output structure for Vault integration
#   - Edge Cases: Empty tags, resource dependencies
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DEFAULTS / MOCKS
# -----------------------------------------------------------------------------

variables {
  compartment_id     = "ocid1.compartment.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  vault_display_name = "test-vault"
  vault_type         = "DEFAULT"
  key_display_name   = "test-key"
  protection_mode    = "SOFTWARE"
  tags = {
    "Environment" = "test"
  }
}

# -----------------------------------------------------------------------------
# KEY SHAPE CONFIGURATION
# -----------------------------------------------------------------------------

# Validates the master encryption key is always configured for AES-256
# The key shape is hardcoded in the module - this ensures it stays correct
run "key_shape_aes256" {
  command = plan

  # -------------------------------------------------------------------------
  # KEY SHAPE ASSERTIONS
  # -------------------------------------------------------------------------

  # Key must use AES algorithm (required for Vault auto-unseal)
  assert {
    condition     = oci_kms_key.this.key_shape[0].algorithm == "AES"
    error_message = "Key algorithm must be AES for Vault compatibility"
  }

  # Key must be 256-bit (32 bytes) for security requirements
  assert {
    condition     = oci_kms_key.this.key_shape[0].length == 32
    error_message = "Key length must be 32 bytes (256-bit)"
  }
}

# -----------------------------------------------------------------------------
# SEAL CONFIGURATION OUTPUT
# -----------------------------------------------------------------------------

# Validates the composite vault_seal_config output contains all required fields
# This output is used directly in HashiCorp Vault configuration
run "seal_config_structure" {
  command = plan

  # -------------------------------------------------------------------------
  # COMPOSITE OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Seal config must include key_id field
  assert {
    condition     = can(output.vault_seal_config.key_id)
    error_message = "vault_seal_config must include key_id"
  }

  # Seal config must include crypto_endpoint field
  assert {
    condition     = can(output.vault_seal_config.crypto_endpoint)
    error_message = "vault_seal_config must include crypto_endpoint"
  }

  # Seal config must include management_endpoint field
  assert {
    condition     = can(output.vault_seal_config.management_endpoint)
    error_message = "vault_seal_config must include management_endpoint"
  }
}

# -----------------------------------------------------------------------------
# EMPTY TAGS EDGE CASE
# -----------------------------------------------------------------------------

# Validates module handles empty tags without errors
run "empty_tags_accepted" {
  command = plan

  variables {
    tags = {}
  }

  # Module should plan successfully with no tags
  assert {
    condition     = oci_kms_vault.this.compartment_id != ""
    error_message = "Module should accept empty tags"
  }
}

# -----------------------------------------------------------------------------
# RESOURCE DEPENDENCY
# -----------------------------------------------------------------------------

# Validates key depends on vault (management_endpoint reference)
run "key_uses_vault_endpoint" {
  command = plan

  # Key must reference vault's management endpoint (implicit dependency)
  assert {
    condition     = oci_kms_key.this.management_endpoint == oci_kms_vault.this.management_endpoint
    error_message = "Key must use vault's management endpoint"
  }
}
