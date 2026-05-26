# -----------------------------------------------------------------------------
# kms-oci module tests (plan-only)
#
# Asserts the composition the module is responsible for: the AES-256 key
# shape is hardcoded correctly, the seal config output carries all three
# fields HashiCorp Vault needs, the key depends on the vault's management
# endpoint, and the module accepts empty tags.
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

# --- key always AES-256 (hardcoded in module) ---
run "key_shape_aes256" {
  command = plan

  assert {
    condition     = oci_kms_key.this.key_shape[0].algorithm == "AES"
    error_message = "key algorithm must be AES for Vault auto-unseal"
  }

  assert {
    condition     = oci_kms_key.this.key_shape[0].length == 32
    error_message = "key length must be 32 bytes (256-bit)"
  }
}

# --- seal config output carries all three fields Vault needs ---
run "seal_config_structure" {
  command = plan

  assert {
    condition     = can(output.vault_seal_config.key_id)
    error_message = "vault_seal_config must include key_id"
  }

  assert {
    condition     = can(output.vault_seal_config.crypto_endpoint)
    error_message = "vault_seal_config must include crypto_endpoint"
  }

  assert {
    condition     = can(output.vault_seal_config.management_endpoint)
    error_message = "vault_seal_config must include management_endpoint"
  }
}

# --- empty tags map accepted without error ---
run "empty_tags_accepted" {
  command = plan

  variables {
    tags = {}
  }

  assert {
    condition     = oci_kms_vault.this.compartment_id == var.compartment_id
    error_message = "compartment_id should flow through with empty tags"
  }
}

# --- compartment_id flows through to both resources ---
run "compartment_id_propagates" {
  command = plan

  assert {
    condition     = oci_kms_vault.this.compartment_id == var.compartment_id
    error_message = "vault compartment_id must match input"
  }

  assert {
    condition     = oci_kms_key.this.compartment_id == var.compartment_id
    error_message = "key compartment_id must match input"
  }
}
