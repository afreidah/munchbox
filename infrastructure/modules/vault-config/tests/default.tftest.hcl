# -------------------------------------------------------------------------------
# VAULT-CONFIG MODULE - TEST SUITE
#
# Project: Munchbox / Author: Alex Freidah
#
# Test Categories:
#   - Baseline: Default configuration with all features enabled
#   - Feature Flags: Verify components can be disabled individually
#   - Conditional Logic: Database roles, workload secrets
#   - Edge Cases: Minimal configuration
# -------------------------------------------------------------------------------

mock_provider "vault" {}
mock_provider "random" {}

# -------------------------------------------------------------------------
# TEST DEFAULTS
# -------------------------------------------------------------------------

variables {
  consul_bootstrap_token = "test-token"
}

# -------------------------------------------------------------------------
# BASELINE TESTS
# -------------------------------------------------------------------------

run "baseline_kv_enabled" {
  command = plan

  assert {
    condition     = length(vault_mount.kv) == 1
    error_message = "KV mount should be created when kv_enabled is true"
  }

  assert {
    condition     = vault_mount.kv[0].path == "secret"
    error_message = "KV mount path should default to 'secret'"
  }
}

run "baseline_consul_secrets_enabled" {
  command = plan

  assert {
    condition     = length(vault_consul_secret_backend.consul) == 1
    error_message = "Consul secrets backend should be created when consul_secrets_enabled is true"
  }
}

run "baseline_jwt_auth_enabled" {
  command = plan

  assert {
    condition     = length(vault_jwt_auth_backend.nomad) == 1
    error_message = "JWT auth backend should be created when jwt_auth_enabled is true"
  }

  assert {
    condition     = length(vault_jwt_auth_backend_role.nomad_workloads) == 1
    error_message = "JWT auth role should be created for nomad workloads"
  }
}

run "baseline_database_disabled_by_default" {
  command = plan

  assert {
    condition     = length(vault_database_secrets_mount.postgres) == 0
    error_message = "Database secrets engine should be disabled by default"
  }
}

run "baseline_pki_roles_created" {
  command = plan

  assert {
    condition     = length(vault_pki_secret_backend_role.traefik) == 1
    error_message = "Traefik PKI role should be created when pki_roles_enabled is true"
  }

  assert {
    condition     = length(vault_pki_secret_backend_role.postgres) == 1
    error_message = "PostgreSQL PKI role should be created when pki_roles_enabled is true"
  }
}

run "baseline_policies_created" {
  command = plan

  assert {
    condition     = length(vault_policy.consul_token_read) == 1
    error_message = "Consul token read policy should be created"
  }

  assert {
    condition     = length(vault_policy.nomad_server) == 1
    error_message = "Nomad server policy should be created"
  }

  assert {
    condition     = length(vault_policy.nomad_client) == 1
    error_message = "Nomad client policy should be created"
  }

  assert {
    condition     = length(vault_policy.nomad_workloads) == 1
    error_message = "Nomad workloads policy should be created"
  }

  assert {
    condition     = length(vault_policy.vault_cert_manager) == 1
    error_message = "Vault cert manager policy should be created"
  }

  assert {
    condition     = length(vault_policy.backup_worker) == 1
    error_message = "Backup worker policy should be created"
  }
}

# -------------------------------------------------------------------------
# FEATURE FLAG TESTS
# -------------------------------------------------------------------------

run "disable_kv" {
  command = plan

  variables {
    kv_enabled = false
  }

  assert {
    condition     = length(vault_mount.kv) == 0
    error_message = "KV mount should not be created when kv_enabled is false"
  }

  assert {
    condition     = length(random_password.postgres_root) == 0
    error_message = "Postgres root password should not be generated when KV is disabled"
  }
}

run "disable_consul_secrets" {
  command = plan

  variables {
    consul_secrets_enabled = false
  }

  assert {
    condition     = length(vault_consul_secret_backend.consul) == 0
    error_message = "Consul secrets backend should not be created when disabled"
  }
}

run "disable_jwt_auth" {
  command = plan

  variables {
    jwt_auth_enabled = false
  }

  assert {
    condition     = length(vault_jwt_auth_backend.nomad) == 0
    error_message = "JWT auth backend should not be created when disabled"
  }

  assert {
    condition     = length(vault_jwt_auth_backend_role.nomad_workloads) == 0
    error_message = "JWT auth role should not be created when JWT auth is disabled"
  }
}

run "enable_database_secrets" {
  command = plan

  variables {
    database_secrets_enabled = true
  }

  assert {
    condition     = length(vault_database_secrets_mount.postgres) == 1
    error_message = "Database secrets engine should be created when enabled"
  }

  assert {
    condition     = length(vault_database_secret_backend_role.temporal) == 1
    error_message = "Temporal database role should be created"
  }

  assert {
    condition     = length(vault_database_secret_backend_role.kanboard) == 1
    error_message = "Kanboard database role should be created"
  }
}

run "disable_pki_roles" {
  command = plan

  variables {
    pki_roles_enabled = false
  }

  assert {
    condition     = length(vault_pki_secret_backend_role.traefik) == 0
    error_message = "Traefik PKI role should not be created when disabled"
  }

  assert {
    condition     = length(vault_pki_secret_backend_role.postgres) == 0
    error_message = "PostgreSQL PKI role should not be created when disabled"
  }
}

run "disable_policies" {
  command = plan

  variables {
    policies_enabled = false
  }

  assert {
    condition     = length(vault_policy.consul_token_read) == 0
    error_message = "Policies should not be created when disabled"
  }

  assert {
    condition     = length(vault_policy.nomad_workloads) == 0
    error_message = "Nomad workloads policy should not be created when disabled"
  }
}

# -------------------------------------------------------------------------
# CONDITIONAL LOGIC TESTS
# -------------------------------------------------------------------------

run "database_roles_subset" {
  command = plan

  variables {
    database_secrets_enabled = true
    database_roles           = ["temporal"]
  }

  assert {
    condition     = length(vault_database_secret_backend_role.temporal) == 1
    error_message = "Temporal role should be created when in database_roles"
  }

  assert {
    condition     = length(vault_database_secret_backend_role.kanboard) == 0
    error_message = "Kanboard role should not be created when not in database_roles"
  }
}

run "custom_workload_secrets" {
  command = plan

  variables {
    workload_secrets = ["custom-app", "another-secret"]
  }

  assert {
    condition     = length(vault_policy.nomad_workloads) == 1
    error_message = "Nomad workloads policy should be created with custom secrets"
  }
}

# -------------------------------------------------------------------------
# EDGE CASES
# -------------------------------------------------------------------------

run "minimal_configuration" {
  command = plan

  variables {
    kv_enabled             = false
    consul_secrets_enabled = false
    jwt_auth_enabled       = false
    pki_roles_enabled      = false
    policies_enabled       = false
  }

  assert {
    condition     = length(vault_mount.kv) == 0
    error_message = "No KV mount with minimal config"
  }

  assert {
    condition     = length(vault_consul_secret_backend.consul) == 0
    error_message = "No Consul backend with minimal config"
  }

  assert {
    condition     = length(vault_jwt_auth_backend.nomad) == 0
    error_message = "No JWT auth with minimal config"
  }

  assert {
    condition     = length(vault_pki_secret_backend_role.traefik) == 0
    error_message = "No PKI roles with minimal config"
  }

  assert {
    condition     = length(vault_policy.nomad_workloads) == 0
    error_message = "No policies with minimal config"
  }
}

run "custom_kv_path" {
  command = plan

  variables {
    kv_path = "custom-kv"
  }

  assert {
    condition     = vault_mount.kv[0].path == "custom-kv"
    error_message = "KV mount should use custom path"
  }
}

run "custom_pki_backend" {
  command = plan

  variables {
    pki_backend_path = "custom-pki"
  }

  assert {
    condition     = vault_pki_secret_backend_role.traefik[0].backend == "custom-pki"
    error_message = "PKI roles should use custom backend path"
  }
}
