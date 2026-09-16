# -----------------------------------------------------------------------------
# s3-orchestrator module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts that one map entry produces one user, one credential, one grant and
# one Vault secret, that the grant carries the bucket and permissions it was
# given, that the keypair lands where a consuming job reads it, and that an
# empty map builds nothing.
# -----------------------------------------------------------------------------

mock_provider "s3orchestrator" {}
mock_provider "vault" {}

variables {
  address = "https://s3.munchbox.cc"
  identities = {
    "temporal-backups-worker" = {
      bucket      = "unified"
      permissions = ["list", "read", "write", "delete"]
      label       = "temporal backup worker"
    }
    "artifacts_terragrunt_reader" = {
      bucket      = "artifacts"
      permissions = ["list", "read"]
    }
  }
}

# -------------------------------------------------------------------------
# One entry onboards one client
# -------------------------------------------------------------------------

run "identities_fan_out" {
  command = plan

  # --- two identities -> two users, two credentials, two grants ---
  assert {
    condition = alltrue([
      length(s3orchestrator_user.this) == 2,
      length(s3orchestrator_credential.this) == 2,
      length(s3orchestrator_grant.this) == 2,
    ])
    error_message = "each identity -> one user, one credential and one grant"
  }

  # --- the grant names the bucket and carries what it was given ---
  assert {
    condition = alltrue([
      s3orchestrator_grant.this["temporal-backups-worker"].name == "unified",
      toset(s3orchestrator_grant.this["artifacts_terragrunt_reader"].permissions) == toset(["list", "read"]),
    ])
    error_message = "grants must carry the bucket and permissions the identity declared"
  }

  # --- the label reaches the credential, which is what an operator reads it by ---
  assert {
    condition     = s3orchestrator_credential.this["temporal-backups-worker"].label == "temporal backup worker"
    error_message = "the identity's label must reach its credential"
  }

  # --- an omitted label stays null rather than becoming an empty string ---
  assert {
    condition     = s3orchestrator_credential.this["artifacts_terragrunt_reader"].label == null
    error_message = "an omitted label must stay null so the orchestrator picks one"
  }

  # --- one Vault secret per identity, keyed the same way ---
  assert {
    condition = toset(keys(vault_kv_secret_v2.identity)) == toset([
      "temporal-backups-worker", "artifacts_terragrunt_reader",
    ])
    error_message = "one Vault secret per identity, keyed by identity name"
  }

  # --- the keypair lands under the prefix, which is what a job's template reads ---
  assert {
    condition     = vault_kv_secret_v2.identity["temporal-backups-worker"].name == "s3-identity/temporal-backups-worker"
    error_message = "keypair must land at <prefix>/<identity>"
  }

  # --- the mount is the KV v2 mount, not part of the name ---
  assert {
    condition     = vault_kv_secret_v2.identity["artifacts_terragrunt_reader"].mount == "secret"
    error_message = "keypair must be written to the configured mount"
  }
}

# -------------------------------------------------------------------------
# An empty map is safe to always call
# -------------------------------------------------------------------------

run "empty_identities" {
  command = plan

  variables {
    identities = {}
  }

  assert {
    condition     = length(vault_kv_secret_v2.identity) == 0
    error_message = "an empty identities map -> no Vault secrets"
  }
}

# -------------------------------------------------------------------------
# The validations refuse the mistakes worth refusing
# -------------------------------------------------------------------------

run "rejects_admin_permission_on_a_bucket" {
  command = plan

  variables {
    identities = {
      "oops" = { bucket = "unified", permissions = ["admin-read"] }
    }
  }

  expect_failures = [var.identities]
}

run "rejects_all_alongside_another_permission" {
  command = plan

  variables {
    identities = {
      "oops" = { bucket = "unified", permissions = ["all", "read"] }
    }
  }

  expect_failures = [var.identities]
}

run "rejects_an_address_without_a_scheme" {
  command = plan

  variables {
    address    = "s3.munchbox.cc"
    identities = {}
  }

  expect_failures = [var.address]
}
