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

mock_provider "tls" {}

variables {
  compartment_id     = "ocid1.compartment.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  tenancy_ocid       = "ocid1.tenancy.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  region             = "us-phoenix-1"
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

# -------------------------------------------------------------------------
# auto-unseal IAM: user/group in tenancy root, policy in key compartment
# -------------------------------------------------------------------------

run "unseal_iam_placement" {
  command = plan

  # --- IAM user lives in the tenancy root, not the key compartment ---
  assert {
    condition     = oci_identity_user.unseal.compartment_id == var.tenancy_ocid
    error_message = "unseal user must be created in the tenancy root"
  }

  # --- group lives in the tenancy root too ---
  assert {
    condition     = oci_identity_group.unseal.compartment_id == var.tenancy_ocid
    error_message = "unseal group must be created in the tenancy root"
  }

  # --- the scoping policy is attached to the key compartment ---
  assert {
    condition     = oci_identity_policy.unseal.compartment_id == var.compartment_id
    error_message = "unseal policy must be in the key compartment"
  }

  # --- the API key is generated with an RSA keypair ---
  assert {
    condition     = tls_private_key.unseal.algorithm == "RSA"
    error_message = "unseal API key must use an RSA keypair"
  }
}

# -------------------------------------------------------------------------
# Outputs surface the vault, key, IAM principal, and seal-config values
# -------------------------------------------------------------------------

run "outputs" {
  command = plan

  # --- pin the computed private-key PEM at plan time so the sensitive
  #     output is assertable (computed attrs are unknown until apply) ---
  override_resource {
    target          = tls_private_key.unseal
    override_during = plan
    values = {
      private_key_pem = "-----BEGIN RSA PRIVATE KEY-----\nMOCK\n-----END RSA PRIVATE KEY-----\n"
      public_key_pem  = "-----BEGIN PUBLIC KEY-----\nMOCK\n-----END PUBLIC KEY-----\n"
    }
  }

  # --- pin the computed API-key fingerprint/key_value at plan time ---
  override_resource {
    target          = oci_identity_api_key.unseal
    override_during = plan
    values = {
      fingerprint = "ab:cd:ef:00:11:22:33:44:55:66:77:88:99:aa:bb:cc"
      key_value   = "-----BEGIN PUBLIC KEY-----\nMOCK\n-----END PUBLIC KEY-----\n"
    }
  }

  # --- pin the computed IAM user OCID at plan time ---
  override_resource {
    target          = oci_identity_user.unseal
    override_during = plan
    values = {
      id = "ocid1.user.oc1..mockmockmockmock"
    }
  }

  # --- pin the computed IAM group OCID at plan time ---
  override_resource {
    target          = oci_identity_group.unseal
    override_during = plan
    values = {
      id = "ocid1.group.oc1..mockmockmockmock"
    }
  }

  # --- pin the membership's computed bindings at plan time ---
  override_resource {
    target          = oci_identity_user_group_membership.unseal
    override_during = plan
    values = {
      user_id  = "ocid1.user.oc1..mockmockmockmock"
      group_id = "ocid1.group.oc1..mockmockmockmock"
    }
  }

  # --- pin the computed key OCID/state at plan time ---
  override_resource {
    target          = oci_kms_key.this
    override_during = plan
    values = {
      id    = "ocid1.key.oc1.phx.mockmockmockmock"
      state = "ENABLED"
    }
  }

  # --- pin the computed vault id/endpoints/state at plan time ---
  override_resource {
    target          = oci_kms_vault.this
    override_during = plan
    values = {
      id                  = "ocid1.vault.oc1.phx.mockmockmockmock"
      state               = "ACTIVE"
      crypto_endpoint     = "https://example-vault-crypto.kms.us-phoenix-1.oraclecloud.com"
      management_endpoint = "https://example-vault.kms.us-phoenix-1.oraclecloud.com"
    }
  }

  # --- display-name outputs mirror the inputs ---
  assert {
    condition     = output.vault_display_name == "test-vault"
    error_message = "vault_display_name output must mirror the input"
  }

  assert {
    condition     = output.key_display_name == "test-key"
    error_message = "key_display_name output must mirror the input"
  }

  # --- protection_mode passes through from the input ---
  assert {
    condition     = output.protection_mode == "SOFTWARE"
    error_message = "protection_mode output must mirror the input"
  }

  # --- region/tenancy outputs come straight from the input variables ---
  assert {
    condition     = output.unseal_region == var.region
    error_message = "unseal_region output must mirror var.region"
  }

  assert {
    condition     = output.unseal_tenancy_ocid == var.tenancy_ocid
    error_message = "unseal_tenancy_ocid output must mirror var.tenancy_ocid"
  }

  # --- computed identifiers are populated (mock supplies arbitrary values) ---
  assert {
    condition     = output.vault_id != null
    error_message = "vault_id output must be set"
  }

  assert {
    condition     = output.vault_state == "ACTIVE"
    error_message = "vault_state output must reflect the vault lifecycle state"
  }

  assert {
    condition     = output.key_id != null
    error_message = "key_id output must be set"
  }

  assert {
    condition     = output.key_state != null
    error_message = "key_state output must be set"
  }

  # --- endpoints come from the mocked vault attributes ---
  assert {
    condition     = output.crypto_endpoint != null
    error_message = "crypto_endpoint output must be set"
  }

  assert {
    condition     = output.management_endpoint != null
    error_message = "management_endpoint output must be set"
  }

  # --- IAM principal outputs are populated (computed OCIDs/fingerprint) ---
  assert {
    condition     = output.unseal_user_ocid != null
    error_message = "unseal_user_ocid output must be set"
  }

  assert {
    condition     = output.unseal_fingerprint != null
    error_message = "unseal_fingerprint output must be set"
  }

  # --- private key PEM is sensitive; assert it is populated via nonsensitive() ---
  assert {
    condition     = length(nonsensitive(output.unseal_private_key_pem)) > 0
    error_message = "unseal_private_key_pem output must be a non-empty PEM"
  }

  # --- vault_seal_config exposes the three seal-stanza keys ---
  assert {
    condition     = toset(keys(output.vault_seal_config)) == toset(["key_id", "crypto_endpoint", "management_endpoint"])
    error_message = "vault_seal_config must expose the ocikms seal-stanza keys"
  }

  # --- the API key binds the generated keypair's public half to the user ---
  assert {
    condition     = oci_identity_api_key.unseal.key_value == tls_private_key.unseal.public_key_pem
    error_message = "API key must use the generated keypair's public key"
  }

  # --- the membership binds the unseal user to the unseal group ---
  assert {
    condition     = oci_identity_user_group_membership.unseal.user_id == oci_identity_user.unseal.id && oci_identity_user_group_membership.unseal.group_id == oci_identity_group.unseal.id
    error_message = "membership must bind the unseal user to the unseal group"
  }
}
