# -----------------------------------------------------------------------------
# postgres-database module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Exercises the manage_secret=true path so the role name is the statically
# known var.app and creds come from a mocked random_password (no vault data
# source dependency). Asserts the role login flag, the for_each fan-out over
# var.databases, and the per-database extension flattening into "db/ext" keys.
# -----------------------------------------------------------------------------

mock_provider "postgresql" {}

mock_provider "vault" {}

mock_provider "random" {}

variables {
  app           = "appuser"
  vault_kv_path = "munchbox/appuser/db"
  databases     = ["db1", "db2"]
  manage_secret = true
  extensions = {
    db1 = ["btree_gin", "pg_trgm"]
  }
}

# -------------------------------------------------------------------------
# manage_secret=true: role name is var.app and the role can log in
# -------------------------------------------------------------------------

run "role_from_app_name" {
  command = plan

  # --- role name is the literal var.app when seeding a new app ---
  assert {
    condition     = postgresql_role.app.name == var.app
    error_message = "role name must equal var.app when manage_secret=true"
  }

  # --- the app role is a login role ---
  assert {
    condition     = postgresql_role.app.login == true
    error_message = "app role must have login enabled"
  }
}

# -------------------------------------------------------------------------
# databases fan out one resource per var.databases entry, keyed by name
# -------------------------------------------------------------------------

run "databases_fan_out" {
  command = plan

  # --- one database resource per input entry ---
  assert {
    condition     = length(postgresql_database.db) == 2
    error_message = "two databases -> two postgresql_database resources"
  }

  # --- for_each keys are the database names themselves ---
  assert {
    condition     = postgresql_database.db["db1"].name == "db1"
    error_message = "db1 resource name must be db1"
  }

  # --- second database also keyed and named by its value ---
  assert {
    condition     = postgresql_database.db["db2"].name == "db2"
    error_message = "db2 resource name must be db2"
  }
}

# -------------------------------------------------------------------------
# extensions flatten into "db/ext" keyed resources
# -------------------------------------------------------------------------

run "extensions_flatten" {
  command = plan

  # --- two extensions on db1 -> two flattened extension resources ---
  assert {
    condition     = length(postgresql_extension.this) == 2
    error_message = "db1 has two extensions -> two postgresql_extension resources"
  }

  # --- flatten key is "<database>/<extension>" ---
  assert {
    condition     = postgresql_extension.this["db1/btree_gin"].name == "btree_gin"
    error_message = "extension key db1/btree_gin must carry name btree_gin"
  }
}

# -------------------------------------------------------------------------
# empty extensions map yields no extension resources
# -------------------------------------------------------------------------

run "no_extensions" {
  command = plan

  variables {
    extensions = {}
  }

  # --- absent extensions -> zero extension resources ---
  assert {
    condition     = length(postgresql_extension.this) == 0
    error_message = "empty extensions map -> no postgresql_extension resources"
  }
}
