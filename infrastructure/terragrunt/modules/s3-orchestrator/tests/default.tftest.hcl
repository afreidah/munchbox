# -----------------------------------------------------------------------------
# s3-orchestrator module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts that one map entry produces one user, one credential and one Vault
# secret however many grants it holds, that a grant carries the kind, target and
# permissions it was given, that the keypair lands where a consuming job reads
# it, and that an empty map builds nothing.
# -----------------------------------------------------------------------------

mock_provider "s3orchestrator" {}
mock_provider "vault" {}

variables {
  address = "https://s3.munchbox.cc"
  identities = {
    "temporal-backups-worker" = {
      label  = "temporal backup worker"
      grants = [{ name = "unified", permissions = ["list", "read", "write", "delete"] }]
    }
    "artifacts_terragrunt_reader" = {
      grants = [{ name = "artifacts", permissions = ["list", "read"] }]
    }
    "admin" = {
      label = "interactive and env-file admin"
      grants = [
        { kind = "bucket", name = "*", permissions = ["all"] },
        { kind = "backend", name = "*", permissions = ["admin-all"] },
        { kind = "orchestrator", permissions = ["admin-all"] },
      ]
    }
  }
}

# -------------------------------------------------------------------------
# One entry onboards one client, whatever it is allowed to reach
# -------------------------------------------------------------------------

run "identities_fan_out" {
  command = plan

  # --- three identities -> three users and credentials, but five grants ---
  assert {
    condition = alltrue([
      length(s3orchestrator_user.this) == 3,
      length(s3orchestrator_credential.this) == 3,
      length(s3orchestrator_grant.this) == 5,
    ])
    error_message = "each identity -> one user and one credential; each of its grants -> one grant"
  }

  # --- the grant names its target and carries what it was given ---
  assert {
    condition = alltrue([
      s3orchestrator_grant.this["temporal-backups-worker/bucket/unified"].name == "unified",
      toset(s3orchestrator_grant.this["artifacts_terragrunt_reader/bucket/artifacts"].permissions) == toset(["list", "read"]),
    ])
    error_message = "grants must carry the target and permissions the identity declared"
  }

  # --- an omitted kind is a bucket grant, which is the common case ---
  assert {
    condition     = s3orchestrator_grant.this["temporal-backups-worker/bucket/unified"].kind == "bucket"
    error_message = "a grant naming no kind must be over a bucket"
  }

  # --- the administrative kinds reach the deployment rather than a bucket ---
  assert {
    condition = alltrue([
      s3orchestrator_grant.this["admin/backend/*"].kind == "backend",
      s3orchestrator_grant.this["admin/orchestrator/"].kind == "orchestrator",
      s3orchestrator_grant.this["admin/orchestrator/"].name == null,
      toset(s3orchestrator_grant.this["admin/orchestrator/"].permissions) == toset(["admin-all"]),
    ])
    error_message = "an orchestrator grant is over the deployment and names nothing"
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

  # --- one Vault secret per identity, not per grant ---
  assert {
    condition = toset(keys(vault_kv_secret_v2.identity)) == toset([
      "temporal-backups-worker", "artifacts_terragrunt_reader", "admin",
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
      "oops" = { grants = [{ name = "unified", permissions = ["admin-read"] }] }
    }
  }

  expect_failures = [var.identities]
}

run "rejects_a_data_plane_permission_on_the_orchestrator" {
  command = plan

  variables {
    identities = {
      "oops" = { grants = [{ kind = "orchestrator", permissions = ["read"] }] }
    }
  }

  expect_failures = [var.identities]
}

run "rejects_an_unknown_kind" {
  command = plan

  variables {
    identities = {
      "oops" = { grants = [{ kind = "cluster", name = "*", permissions = ["admin-all"] }] }
    }
  }

  expect_failures = [var.identities]
}

run "rejects_a_named_orchestrator_grant" {
  command = plan

  variables {
    identities = {
      "oops" = { grants = [{ kind = "orchestrator", name = "*", permissions = ["admin-all"] }] }
    }
  }

  expect_failures = [var.identities]
}

run "rejects_a_bucket_grant_naming_nothing" {
  command = plan

  variables {
    identities = {
      "oops" = { grants = [{ permissions = ["read"] }] }
    }
  }

  expect_failures = [var.identities]
}

run "rejects_an_identity_holding_no_grants" {
  command = plan

  variables {
    identities = {
      "oops" = { grants = [] }
    }
  }

  expect_failures = [var.identities]
}

run "rejects_two_grants_over_the_same_target" {
  command = plan

  variables {
    identities = {
      "oops" = {
        grants = [
          { name = "unified", permissions = ["read"] },
          { name = "unified", permissions = ["write"] },
        ]
      }
    }
  }

  expect_failures = [var.identities]
}

run "rejects_all_alongside_another_permission" {
  command = plan

  variables {
    identities = {
      "oops" = { grants = [{ name = "unified", permissions = ["all", "read"] }] }
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
