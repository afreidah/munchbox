# -----------------------------------------------------------------------------
# vault-config module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the module's composition: each feature flag toggles its resource
# set, for_each maps fan out the expected keys, the JWT/PKI plumbing wires
# up correctly, and minimal-config edge case produces zero managed resources.
# -----------------------------------------------------------------------------

mock_provider "vault" {
  # --- data.vault_generic_secret.pki_int_ca needs a known .data.certificate at plan time ---
  mock_data "vault_generic_secret" {
    defaults = {
      data = {
        certificate = "-----BEGIN CERTIFICATE-----\nMIIDmocktest\n-----END CERTIFICATE-----"
      }
    }
  }
}

mock_provider "random" {}

variables {
  consul_bootstrap_token = "test-token"
}

# -------------------------------------------------------------------------
# KV mount enabled by default at path "secret"
# -------------------------------------------------------------------------

run "baseline_kv_enabled" {
  command = plan

  # --- kv mount resource is created (count = 1) ---
  assert {
    condition     = length(vault_mount.kv) == 1
    error_message = "KV mount should be created when kv_enabled is true"
  }

  # --- default mount path is "secret" ---
  assert {
    condition     = vault_mount.kv[0].path == "secret"
    error_message = "KV mount path should default to 'secret'"
  }
}

# -------------------------------------------------------------------------
# Consul secrets backend enabled by default
# -------------------------------------------------------------------------

run "baseline_consul_secrets_enabled" {
  command = plan

  # --- consul backend resource is created ---
  assert {
    condition     = length(vault_consul_secret_backend.consul) == 1
    error_message = "Consul secrets backend should be created when consul_secrets_enabled is true"
  }
}

# -------------------------------------------------------------------------
# JWT auth backend + nomad-workloads role enabled by default
# -------------------------------------------------------------------------

run "baseline_jwt_auth_enabled" {
  command = plan

  # --- JWT auth backend created ---
  assert {
    condition     = length(vault_jwt_auth_backend.nomad) == 1
    error_message = "JWT auth backend should be created when jwt_auth_enabled is true"
  }

  # --- nomad-workloads role attached ---
  assert {
    condition     = length(vault_jwt_auth_backend_role.nomad_workloads) == 1
    error_message = "JWT auth role 'nomad-workloads' should be created"
  }
}

# -------------------------------------------------------------------------
# Database secrets disabled by default (off unless explicit opt-in)
# -------------------------------------------------------------------------

run "baseline_database_disabled_by_default" {
  command = plan

  # --- database secrets mount stays off without explicit enable ---
  assert {
    condition     = length(vault_database_secrets_mount.postgres) == 0
    error_message = "Database secrets mount should be off by default"
  }
}

# -------------------------------------------------------------------------
# PKI roles for_each fans out to the keys passed
# -------------------------------------------------------------------------

run "baseline_pki_roles_created" {
  command = plan

  variables {
    pki_roles = {
      traefik  = { allowed_domains = ["munchbox.cc"], max_ttl = "8760h", ttl = "720h" }
      postgres = { allowed_domains = ["postgres.consul"], max_ttl = "720h", ttl = "72h" }
    }
  }

  # --- two pki_roles keys -> two role resources ---
  assert {
    condition     = length(vault_pki_secret_backend_role.role) == 2
    error_message = "Both PKI roles should be created from for_each"
  }

  # --- traefik role key exists ---
  assert {
    condition     = contains(keys(vault_pki_secret_backend_role.role), "traefik")
    error_message = "PKI role 'traefik' should exist in the map"
  }

  # --- postgres role key exists ---
  assert {
    condition     = contains(keys(vault_pki_secret_backend_role.role), "postgres")
    error_message = "PKI role 'postgres' should exist in the map"
  }
}

# -------------------------------------------------------------------------
# vault_policies for_each fans out to the keys passed
# -------------------------------------------------------------------------

run "baseline_policies_created" {
  command = plan

  variables {
    vault_policies = {
      "consul-token-read"  = { policy = "path \"x\" { capabilities = [\"read\"] }" }
      "nomad-server"       = { policy = "path \"y\" { capabilities = [\"read\"] }" }
      "vault-cert-manager" = { policy = "path \"z\" { capabilities = [\"read\"] }" }
    }
  }

  # --- three vault_policies keys -> three policy resources ---
  assert {
    condition     = length(vault_policy.policy) == 3
    error_message = "All three policies should be created from for_each"
  }

  # --- consul-token-read key exists ---
  assert {
    condition     = contains(keys(vault_policy.policy), "consul-token-read")
    error_message = "Policy 'consul-token-read' should exist"
  }
}

# -------------------------------------------------------------------------
# disable_kv: KV mount is gated off when kv_enabled = false
# -------------------------------------------------------------------------

run "disable_kv" {
  command = plan

  variables {
    kv_enabled = false
  }

  # --- KV mount count drops to 0 when disabled ---
  assert {
    condition     = length(vault_mount.kv) == 0
    error_message = "KV mount should be skipped when kv_enabled = false"
  }
}

# -------------------------------------------------------------------------
# disable_consul_secrets gates the backend off
# -------------------------------------------------------------------------

run "disable_consul_secrets" {
  command = plan

  variables {
    consul_secrets_enabled = false
  }

  # --- consul backend count drops to 0 when disabled ---
  assert {
    condition     = length(vault_consul_secret_backend.consul) == 0
    error_message = "Consul backend should not be created when disabled"
  }
}

# -------------------------------------------------------------------------
# disable_jwt_auth: backend + role both off
# -------------------------------------------------------------------------

run "disable_jwt_auth" {
  command = plan

  variables {
    jwt_auth_enabled = false
  }

  # --- JWT backend drops to 0 ---
  assert {
    condition     = length(vault_jwt_auth_backend.nomad) == 0
    error_message = "JWT backend should not be created when disabled"
  }

  # --- JWT role drops to 0 ---
  assert {
    condition     = length(vault_jwt_auth_backend_role.nomad_workloads) == 0
    error_message = "JWT role should not be created when JWT is disabled"
  }
}

# -------------------------------------------------------------------------
# enable_database_secrets with two roles fans out per key
# -------------------------------------------------------------------------

run "enable_database_secrets" {
  command = plan

  variables {
    database_secrets_enabled = true
    database_roles = {
      temporal = { creation_statements = ["CREATE ROLE x;"] }
      kanboard = { creation_statements = ["CREATE ROLE y;"] }
    }
  }

  # --- database mount fires when explicitly enabled ---
  assert {
    condition     = length(vault_database_secrets_mount.postgres) == 1
    error_message = "Database secrets mount should be created when enabled"
  }

  # --- two roles -> two role resources via for_each ---
  assert {
    condition     = length(vault_database_secret_backend_role.role) == 2
    error_message = "Both database roles should be created from for_each"
  }

  # --- 'temporal' key exists in the role map ---
  assert {
    condition     = contains(keys(vault_database_secret_backend_role.role), "temporal")
    error_message = "Database role 'temporal' should exist"
  }
}

# -------------------------------------------------------------------------
# disable_pki_roles: for_each map is empty regardless of var.pki_roles
# -------------------------------------------------------------------------

run "disable_pki_roles" {
  command = plan

  variables {
    pki_roles_enabled = false
    pki_roles = {
      traefik = { allowed_domains = ["munchbox.cc"], max_ttl = "8760h", ttl = "720h" }
    }
  }

  # --- pki_roles input ignored when feature flag is off ---
  assert {
    condition     = length(vault_pki_secret_backend_role.role) == 0
    error_message = "No PKI roles should be created when pki_roles_enabled = false"
  }
}

# -------------------------------------------------------------------------
# disable_policies: for_each map empty + named nomad_workloads off
# -------------------------------------------------------------------------

run "disable_policies" {
  command = plan

  variables {
    policies_enabled = false
    vault_policies = {
      "p1" = { policy = "path \"x\" { capabilities = [\"read\"] }" }
    }
  }

  # --- vault_policies map yields zero resources when feature disabled ---
  assert {
    condition     = length(vault_policy.policy) == 0
    error_message = "No vault policies should be created when policies_enabled = false"
  }

  # --- nomad_workloads named policy also drops to zero ---
  assert {
    condition     = length(vault_policy.nomad_workloads) == 0
    error_message = "Nomad workloads policy should be off when policies_enabled = false"
  }
}

# -------------------------------------------------------------------------
# database_roles subset: only the provided key creates a role
# -------------------------------------------------------------------------

run "database_roles_subset" {
  command = plan

  variables {
    database_secrets_enabled = true
    database_roles = {
      temporal = { creation_statements = ["CREATE ROLE x;"] }
    }
  }

  # --- one role input -> one role resource ---
  assert {
    condition     = length(vault_database_secret_backend_role.role) == 1
    error_message = "Only one role should be created when only one key is in the map"
  }

  # --- the surviving key is the one we provided ---
  assert {
    condition     = contains(keys(vault_database_secret_backend_role.role), "temporal")
    error_message = "The remaining role key should be 'temporal'"
  }
}

# -------------------------------------------------------------------------
# Custom workload_secrets list is accepted (nomad_workloads still created)
# -------------------------------------------------------------------------

run "custom_workload_secrets" {
  command = plan

  variables {
    workload_secrets = ["custom-app", "another-secret"]
  }

  # --- workload_secrets > 0 triggers the nomad_workloads policy ---
  assert {
    condition     = length(vault_policy.nomad_workloads) == 1
    error_message = "Nomad workloads policy should still be created with custom secret list"
  }
}

# -------------------------------------------------------------------------
# Minimal config: every flag off, everything count = 0
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

  # --- no KV mount ---
  assert {
    condition     = length(vault_mount.kv) == 0
    error_message = "No KV with minimal config"
  }

  # --- no consul backend ---
  assert {
    condition     = length(vault_consul_secret_backend.consul) == 0
    error_message = "No Consul backend with minimal config"
  }

  # --- no JWT auth ---
  assert {
    condition     = length(vault_jwt_auth_backend.nomad) == 0
    error_message = "No JWT auth with minimal config"
  }

  # --- no PKI roles ---
  assert {
    condition     = length(vault_pki_secret_backend_role.role) == 0
    error_message = "No PKI roles with minimal config"
  }

  # --- no nomad_workloads named policy ---
  assert {
    condition     = length(vault_policy.nomad_workloads) == 0
    error_message = "No nomad_workloads policy with minimal config"
  }
}
