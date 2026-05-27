# -----------------------------------------------------------------------------
# kms-oci module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the composition the module is responsible for: the AES-256 key
# shape is hardcoded, compartment_id propagates to every resource, and an
# empty tags map is accepted without error. The vault_seal_config output
# is pure static HCL composition — not plan-resolvable, not asserted here.
# -----------------------------------------------------------------------------

mock_provider "oci" {
  mock_resource "oci_kms_vault" {
    defaults = {
      id                  = "ocid1.vault.oc1.phx.mockmockmockmock"
      management_endpoint = "https://example-vault.kms.us-phoenix-1.oraclecloud.com"
      crypto_endpoint     = "https://example-vault-crypto.kms.us-phoenix-1.oraclecloud.com"
      state               = "ACTIVE"
    }
  }

}

variables {
  compartment_id     = "ocid1.compartment.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  vault_display_name = "test-vault"
  vault_type         = "DEFAULT"
  key_display_name   = "test-key"
  protection_mode    = "SOFTWARE"
  tags               = { Environment = "test" }
}

# -------------------------------------------------------------------------
# Master encryption key shape is hardcoded AES-256
# -------------------------------------------------------------------------

run "key_shape_aes256" {
  command = plan

  # --- algorithm is AES (required for Vault auto-unseal) ---
  assert {
    condition     = oci_kms_key.this.key_shape[0].algorithm == "AES"
    error_message = "key algorithm must be AES for Vault auto-unseal"
  }

  # --- key length is 32 bytes (256-bit) ---
  assert {
    condition     = oci_kms_key.this.key_shape[0].length == 32
    error_message = "key length must be 32 bytes (256-bit)"
  }
}

# -------------------------------------------------------------------------
# Empty tags map is accepted (edge case for free-tier deployments)
# -------------------------------------------------------------------------

run "empty_tags_accepted" {
  command = plan

  variables {
    tags = {}
  }

  # --- module plans cleanly with no tags; compartment_id still flows ---
  assert {
    condition     = oci_kms_vault.this.compartment_id == var.compartment_id
    error_message = "compartment_id should flow through with empty tags"
  }
}

# -------------------------------------------------------------------------
# compartment_id propagates to both the vault and the key
# -------------------------------------------------------------------------

run "compartment_id_propagates" {
  command = plan

  # --- vault is in the right compartment ---
  assert {
    condition     = oci_kms_vault.this.compartment_id == var.compartment_id
    error_message = "vault compartment_id must match input"
  }

  # --- key is in the right compartment ---
  assert {
    condition     = oci_kms_key.this.compartment_id == var.compartment_id
    error_message = "key compartment_id must match input"
  }
}
